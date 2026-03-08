"""
routes/optimisation_routes.py — Endpoints pour l'optimisation VRP

Ces endpoints sont le cœur de l'application.
Ils orchestrent l'algorithme NSGA-II et le graphe routier.

Endpoints disponibles :
  POST /optimisation/init      → initialiser le graphe routier (obligatoire avant tout)
  POST /optimisation/lancer    → lancer NSGA-II sur les commandes acceptées
  GET  /optimisation/solution  → récupérer la meilleure solution calculée
  GET  /optimisation/pareto    → récupérer le front de Pareto complet
  POST /optimisation/reset     → remettre tout à zéro
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks
from typing import List
from Schemas import OptimisationParams, SolutionOut, RouteInfo, ParetoPoint
from State import app_state, REF_LAT, REF_LON
import vrp_nsga2 as vrp

router = APIRouter(prefix="/optimisation", tags=["Optimisation"])


@router.post("/init", summary="Initialiser le graphe routier")
def initialiser_graphe():
    """
    **Étape obligatoire avant toute optimisation.**

    Cette route :
    1. Convertit toutes les coordonnées GPS (lat/lon) en km locaux (x/y)
       par rapport au point de référence (centre d'Alger).
    2. Construit un graphe routier synthétique avec 30 nœuds.
    3. Mappe chaque conducteur et commande au nœud le plus proche.
    4. Précalcule la matrice de distances entre les nœuds utiles (Dijkstra optimisé).

    Doit être relancée si :
    - On ajoute/supprime des conducteurs ou commandes
    - On change les commandes acceptées
    """
    if not app_state.conducteurs:
        raise HTTPException(status_code=400,
            detail="Aucun conducteur enregistré. Ajoutez des conducteurs d'abord.")

    commandes_acceptees = app_state.gestionnaire.get_acceptees()
    if not commandes_acceptees:
        raise HTTPException(status_code=400,
            detail="Aucune commande acceptée. Acceptez des commandes d'abord.")

    vrp.init_road_graph(
        conducteurs=app_state.conducteurs,
        commandes=commandes_acceptees,
        ref_lat=REF_LAT,
        ref_lon=REF_LON,
        num_nodes=30
    )
    app_state.graph_ready = True

    return {
        "message": "Graphe routier initialisé avec succès.",
        "nb_conducteurs": len(app_state.conducteurs),
        "nb_commandes_acceptees": len(commandes_acceptees),
        "ref_lat": REF_LAT,
        "ref_lon": REF_LON
    }


@router.post("/lancer", response_model=SolutionOut, summary="Lancer l'optimisation NSGA-II")
def lancer_optimisation(params: OptimisationParams = OptimisationParams()):
    """
    **Lance l'algorithme NSGA-II sur les commandes acceptées.**

    NSGA-II (Non-dominated Sorting Genetic Algorithm II) est un algorithme
    génétique multi-objectif qui optimise simultanément :
    - **Distance totale** : minimiser les km parcourus par tous les conducteurs
    - **Déséquilibre de charge** : équilibrer la charge entre conducteurs

    Au lieu d'une seule solution, il produit un **front de Pareto** :
    un ensemble de solutions représentant les meilleurs compromis possibles.

    La réponse retourne la solution avec la **distance minimale**.

    Paramètres :
    - `pop_size` : nombre de solutions évaluées par génération (défaut: 30)
    - `generations` : nombre d'itérations de l'algorithme (défaut: 80)
    - `seed` : graine aléatoire pour reproductibilité
    """
    if not app_state.graph_ready:
        raise HTTPException(status_code=400,
            detail="Graphe non initialisé. Appelez POST /optimisation/init d'abord.")

    commandes_acceptees = app_state.gestionnaire.get_acceptees()
    nb = len(commandes_acceptees)

    if nb == 0:
        raise HTTPException(status_code=400, detail="Aucune commande acceptée à livrer.")

    # ── Cas 1 commande : route directe, pas besoin de NSGA-II ────────────
    if nb == 1:
        cid_unique = list(commandes_acceptees.keys())[0]
        solution, meilleur_conducteur, distance = vrp.route_directe(
            app_state.conducteurs,
            commandes_acceptees[cid_unique]
        )
        app_state.solution = solution
        app_state.fitnesses = [(distance, 0)]

    # ── Cas plusieurs commandes : NSGA-II ─────────────────────────────────
    else:
        solutions, fitnesses = vrp.nsga2(
            conducteurs=app_state.conducteurs,
            commandes=commandes_acceptees,
            pop_size=params.pop_size,
            generations=params.generations,
            seed=params.seed
        )
        app_state.fitnesses = fitnesses

        # Sélectionner la solution avec la distance minimale
        best_idx = min(range(len(fitnesses)), key=lambda i: fitnesses[i][0])
        app_state.solution = solutions[best_idx]

    return _build_solution_out(commandes_acceptees)


@router.get("/solution", response_model=SolutionOut, summary="Récupérer la solution courante")
def obtenir_solution():
    """
    Retourne la meilleure solution calculée lors du dernier appel à `/lancer`.

    Chaque route indique :
    - les commandes à livrer (dans l'ordre)
    - la charge totale vs capacité du conducteur
    - la distance estimée en km
    """
    if app_state.solution is None:
        raise HTTPException(status_code=404,
            detail="Aucune solution disponible. Lancez POST /optimisation/lancer.")

    commandes_acceptees = app_state.gestionnaire.get_acceptees()
    return _build_solution_out(commandes_acceptees)


@router.get("/pareto", response_model=List[ParetoPoint], summary="Front de Pareto")
def obtenir_pareto():
    """
    Retourne tous les points du front de Pareto de la dernière optimisation.

    Le front de Pareto est l'ensemble des solutions **non dominées** :
    aucune autre solution n'est meilleure sur les deux objectifs en même temps.

    Chaque point représente un compromis différent entre :
    - distance minimale (axe X)
    - charge équilibrée (axe Y)

    Utilisez ces données pour tracer le graphe front de Pareto côté frontend.
    """
    if app_state.fitnesses is None:
        raise HTTPException(status_code=404,
            detail="Pas de données Pareto. Lancez d'abord POST /optimisation/lancer.")

    fitnesses = app_state.fitnesses
    pareto_points = []
    for i, fi in enumerate(fitnesses):
        dominated = any(
            fj[0] <= fi[0] and fj[1] <= fi[1] and (fj[0] < fi[0] or fj[1] < fi[1])
            for j, fj in enumerate(fitnesses) if i != j
        )
        if not dominated:
            pareto_points.append(ParetoPoint(
                distance_km=round(fi[0], 2),
                desequilibre=round(fi[1], 2)
            ))

    # Trier par distance croissante
    pareto_points.sort(key=lambda p: p.distance_km)
    return pareto_points


@router.post("/reset", summary="Remettre l'état à zéro")
def reset():
    """
    Remet complètement l'état de l'application à zéro :
    conducteurs, commandes, solution, graphe.

    Utile pour commencer un nouveau scénario de livraison.
    """
    app_state.reset()
    return {"message": "État remis à zéro."}


# ─── Helper privé ────────────────────────────────────────────────────────────

def _build_solution_out(commandes_acceptees: dict) -> SolutionOut:
    """Construit l'objet SolutionOut à partir de l'état global."""
    routes = []
    for conducteur in app_state.conducteurs:
        route = app_state.solution[conducteur.id]
        charge = vrp.route_load(route, commandes_acceptees)
        distance = vrp.route_distance(route, commandes_acceptees, conducteur)
        routes.append(RouteInfo(
            conducteur_id=conducteur.id,
            conducteur_nom=conducteur.nom,
            route=route,
            charge=charge,
            capacite=conducteur.capacity,
            distance_km=round(distance, 2)
        ))

    fit = vrp.evaluate(app_state.solution, app_state.conducteurs, commandes_acceptees)
    return SolutionOut(
        routes=routes,
        distance_totale_km=round(fit[0], 2),
        desequilibre=round(fit[1], 2),
        valide=vrp.is_valid(app_state.solution, app_state.conducteurs, commandes_acceptees),
        nb_commandes=len(commandes_acceptees)
    )