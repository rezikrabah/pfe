"""
VRP Backend API — FastAPI
Expose your NSGA-II optimization engine as REST endpoints
for the Flutter frontend.
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Optional
import uuid
import os
import asyncio
from concurrent.futures import ThreadPoolExecutor

# ── Import your existing modules ──────────────────────────
from models import Commande, Conducteur, GestionnaireCommandes
from vrp_nsga2 import (
    init_road_graph, update_conducteur_position,
    route_load, evaluate, is_valid,
    nsga2, route_directe, ajouter_commande
)

# ==========================================================
app = FastAPI(
    title="VRP Optimization API",
    description="Vehicle Routing Problem with NSGA-II — Algiers delivery system",
    version="1.0.0"
)

# Allow Flutter app (any origin during development)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

executor = ThreadPoolExecutor(max_workers=2)

# ── GPS reference point (Alger centre) ───────────────────
REF_LAT = 36.7538
REF_LON = 3.0588

# ── In-memory state (replace with DB in production) ──────
state = {
    "conducteurs": [],
    "gestionnaire": GestionnaireCommandes(),
    "current_solution": None,
    "initialized": False,
}


# ==========================================================
# REQUEST / RESPONSE SCHEMAS
# ==========================================================

class ConducteurIn(BaseModel):
    id: int
    capacity: int
    lat: float
    lon: float
    nom: str

class CommandeIn(BaseModel):
    id: int
    lat: float
    lon: float
    demand: int
    description: str = ""

class GPSUpdateIn(BaseModel):
    conducteur_id: int
    lat: float
    lon: float

class AcceptRefuseIn(BaseModel):
    commande_id: int

class RoutePoint(BaseModel):
    commande_id: int
    lat: float
    lon: float
    demand: int
    description: str

class ConducteurRoute(BaseModel):
    id: int
    nom: str
    lat: float
    lon: float
    capacity: int
    load: int
    route: list[RoutePoint]

class SolutionResponse(BaseModel):
    valid: bool
    total_distance_km: float
    imbalance: float
    conducteurs: list[ConducteurRoute]

class StatusResponse(BaseModel):
    message: str
    success: bool


# ==========================================================
# HELPER
# ==========================================================

def _solution_to_response(solution, conducteurs, commandes) -> SolutionResponse:
    """Convert internal solution dict → API response model."""
    fit = evaluate(solution, conducteurs, commandes)
    valid = is_valid(solution, conducteurs, commandes)
    routes = []
    for c in conducteurs:
        route_ids = solution[c.id]
        points = [
            RoutePoint(
                commande_id=cid,
                lat=commandes[cid].lat,
                lon=commandes[cid].lon,
                demand=commandes[cid].demand,
                description=commandes[cid].description,
            )
            for cid in route_ids
        ]
        routes.append(ConducteurRoute(
            id=c.id,
            nom=c.nom,
            lat=c.lat,
            lon=c.lon,
            capacity=c.capacity,
            load=route_load(route_ids, commandes),
            route=points,
        ))
    return SolutionResponse(
        valid=valid,
        total_distance_km=round(fit[0], 2),
        imbalance=round(fit[1], 2),
        conducteurs=routes,
    )


# ==========================================================
# ENDPOINTS
# ==========================================================

# ── 1. SETUP ──────────────────────────────────────────────

@app.post("/setup/conducteurs", response_model=StatusResponse, tags=["Setup"])
def setup_conducteurs(conducteurs_in: list[ConducteurIn]):
    """
    Initialize the list of drivers with their real GPS positions.
    Call this once at app startup.
    """
    state["conducteurs"] = [
        Conducteur(c.id, capacity=c.capacity, lat=c.lat, lon=c.lon, nom=c.nom)
        for c in conducteurs_in
    ]
    state["initialized"] = False
    return StatusResponse(message=f"{len(state['conducteurs'])} conducteurs enregistres.", success=True)


@app.post("/setup/init-graph", response_model=StatusResponse, tags=["Setup"])
def init_graph(num_nodes: int = 30):
    """
    Build the road graph and distance matrix.
    Must be called AFTER adding conducteurs and at least some commandes.
    """
    conducteurs = state["conducteurs"]
    if not conducteurs:
        raise HTTPException(400, "Aucun conducteur enregistre. Appelez /setup/conducteurs d'abord.")

    commandes = state["gestionnaire"].get_acceptees()
    init_road_graph(conducteurs, commandes, REF_LAT, REF_LON, num_nodes=num_nodes)
    state["initialized"] = True
    return StatusResponse(message="Graphe routier initialise.", success=True)


# ── 2. COMMANDES (Orders) ─────────────────────────────────

@app.post("/commandes/add", response_model=StatusResponse, tags=["Orders"])
def add_commande(cmd: CommandeIn):
    """Add a new pending order."""
    state["gestionnaire"].ajouter(
        Commande(cmd.id, cmd.lat, cmd.lon, cmd.demand, cmd.description)
    )
    return StatusResponse(message=f"Commande {cmd.id} ajoutee.", success=True)


@app.post("/commandes/accept", response_model=StatusResponse, tags=["Orders"])
def accept_commande(body: AcceptRefuseIn):
    """Supplier accepts an order."""
    result = state["gestionnaire"].accepter(body.commande_id)
    if not result:
        raise HTTPException(404, f"Commande {body.commande_id} introuvable ou deja traitee.")
    return StatusResponse(message=f"Commande {body.commande_id} acceptee.", success=True)


@app.post("/commandes/refuse", response_model=StatusResponse, tags=["Orders"])
def refuse_commande(body: AcceptRefuseIn):
    """Supplier refuses an order."""
    result = state["gestionnaire"].refuser(body.commande_id)
    if not result:
        raise HTTPException(404, f"Commande {body.commande_id} introuvable.")
    return StatusResponse(message=f"Commande {body.commande_id} refusee.", success=True)


@app.get("/commandes", tags=["Orders"])
def list_commandes():
    """List all orders with their status."""
    return [
        {
            "id": c.id,
            "lat": c.lat,
            "lon": c.lon,
            "demand": c.demand,
            "description": c.description,
            "statut": c.statut,
        }
        for c in state["gestionnaire"].commandes.values()
    ]


# ── 3. OPTIMIZATION ───────────────────────────────────────

@app.post("/optimize", response_model=SolutionResponse, tags=["Optimization"])
def optimize(pop_size: int = 30, generations: int = 80):
    """
    Run NSGA-II optimization on accepted orders.
    Always re-initializes the graph so all node_ids are fresh.
    """
    conducteurs = state["conducteurs"]
    if not conducteurs:
        raise HTTPException(400, "Aucun conducteur enregistre. Appelez /setup/conducteurs d'abord.")

    commandes = state["gestionnaire"].get_acceptees()
    if not commandes:
        raise HTTPException(400, "Aucune commande acceptee a optimiser.")

    # Always re-init graph before optimizing
    # This ensures ALL conducteurs and commandes have valid node_ids
    init_road_graph(conducteurs, commandes, REF_LAT, REF_LON, num_nodes=30)
    state["initialized"] = True

    nb = len(commandes)
    if nb == 1:
        cid = list(commandes.keys())[0]
        solution, _, _ = route_directe(conducteurs, commandes[cid])
    else:
        solutions, fitnesses = nsga2(
            conducteurs, commandes,
            pop_size=pop_size, generations=generations, seed=0
        )
        best_idx = min(range(len(fitnesses)), key=lambda i: fitnesses[i][0])
        solution = solutions[best_idx]

    state["current_solution"] = solution
    return _solution_to_response(solution, conducteurs, commandes)


@app.get("/solution", response_model=SolutionResponse, tags=["Optimization"])
def get_current_solution():
    """Get the last computed solution."""
    solution = state["current_solution"]
    if not solution:
        raise HTTPException(404, "Aucune solution calculee. Appelez /optimize d'abord.")

    conducteurs = state["conducteurs"]
    commandes   = state["gestionnaire"].get_acceptees()

    # If node_ids are missing (e.g. after backend restart), re-init graph
    needs_reinit = any(c.node_id is None for c in conducteurs) or \
                   any(c.node_id is None for c in commandes.values())
    if needs_reinit or not state["initialized"]:
        if not conducteurs or not commandes:
            raise HTTPException(503, "Backend redemarré. Veuillez re-accepter une commande pour recalculer.")
        init_road_graph(conducteurs, commandes, REF_LAT, REF_LON, num_nodes=30)
        state["initialized"] = True

    return _solution_to_response(solution, conducteurs, commandes)


# ── 4. REAL-TIME GPS ──────────────────────────────────────

@app.post("/gps/update", response_model=StatusResponse, tags=["GPS"])
def update_gps(body: GPSUpdateIn):
    """
    Update a driver's real-time GPS position.
    Flutter sends this periodically (e.g., every 10 seconds).
    """
    if not state["initialized"]:
        raise HTTPException(400, "Graphe non initialise.")

    conducteurs = state["conducteurs"]
    target = next((c for c in conducteurs if c.id == body.conducteur_id), None)
    if not target:
        raise HTTPException(404, f"Conducteur {body.conducteur_id} introuvable.")

    update_conducteur_position(target, new_lat=body.lat, new_lon=body.lon)
    return StatusResponse(
        message=f"Position de {target.nom} mise a jour: ({body.lat}, {body.lon})",
        success=True
    )


@app.get("/gps/positions", tags=["GPS"])
def get_all_positions():
    """Get current GPS position of all drivers."""
    return [
        {
            "id": c.id,
            "nom": c.nom,
            "lat": c.lat,
            "lon": c.lon,
        }
        for c in state["conducteurs"]
    ]


# ── 5. DYNAMIC ORDER INSERTION ────────────────────────────

@app.post("/commandes/insert-dynamic", response_model=SolutionResponse, tags=["Orders"])
def insert_dynamic(cmd: CommandeIn):
    """
    Add a new order dynamically to an existing solution
    using cheapest insertion (no full re-optimization needed).
    """
    if not state["current_solution"]:
        raise HTTPException(400, "Aucune solution en cours. Optimisez d'abord.")
    if not state["initialized"]:
        raise HTTPException(400, "Graphe non initialise.")

    conducteurs = state["conducteurs"]
    commandes = state["gestionnaire"].get_acceptees()
    nouvelle = Commande(cmd.id, cmd.lat, cmd.lon, cmd.demand, cmd.description)

    # Also register in gestionnaire
    state["gestionnaire"].ajouter(nouvelle)
    state["gestionnaire"].accepter(cmd.id)

    updated = ajouter_commande(
        state["current_solution"], conducteurs, commandes, nouvelle
    )
    state["current_solution"] = updated
    commandes_updated = state["gestionnaire"].get_acceptees()
    return _solution_to_response(updated, conducteurs, commandes_updated)


# ── 6. HEALTH ─────────────────────────────────────────────

@app.get("/health", tags=["System"])
def health():
    return {
        "status": "ok",
        "conducteurs": len(state["conducteurs"]),
        "commandes_total": len(state["gestionnaire"].commandes),
        "commandes_acceptees": len(state["gestionnaire"].get_acceptees()),
        "graph_initialized": state["initialized"],
        "solution_available": state["current_solution"] is not None,
    }


# ==========================================================
# RUN
# ==========================================================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api:app", host="0.0.0.0", port=8000, reload=True)