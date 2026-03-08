"""
routes/commande_routes.py — Endpoints pour gérer les commandes

Endpoints disponibles :
  POST   /commandes/              → soumettre une nouvelle commande
  GET    /commandes/              → lister toutes les commandes (filtrable par statut)
  GET    /commandes/{id}          → détail d'une commande
  PUT    /commandes/{id}/decision → accepter ou refuser
  DELETE /commandes/{id}          → supprimer une commande
  POST   /commandes/{id}/ajouter-dynamique → insérer dans la solution en cours
"""

from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from Schemas import CommandeCreate, CommandeOut, DecisionBody
from models import Commande
from State import app_state
import vrp_nsga2 as vrp

router = APIRouter(prefix="/commandes", tags=["Commandes"])


@router.post("/", response_model=CommandeOut, status_code=201)
def soumettre_commande(data: CommandeCreate):
    """
    Enregistre une nouvelle commande en statut 'en_attente'.
    Le fournisseur devra ensuite l'accepter ou la refuser.
    """
    if data.id in app_state.gestionnaire.commandes:
        raise HTTPException(status_code=409, detail=f"Commande {data.id} existe déjà.")

    commande = Commande(
        cid=data.id,
        lat=data.lat,
        lon=data.lon,
        demand=data.demand,
        description=data.description or ""
    )
    app_state.gestionnaire.ajouter(commande)
    return _to_out(commande)


@router.get("/", response_model=List[CommandeOut])
def lister_commandes(statut: Optional[str] = Query(
        None,
        description="Filtrer par statut : 'en_attente', 'acceptee', 'refusee'"
    )):
    """
    Retourne toutes les commandes.
    Utilisez ?statut=acceptee pour ne voir que les commandes acceptées.
    """
    commandes = app_state.gestionnaire.commandes.values()
    if statut:
        commandes = [c for c in commandes if c.statut == statut]
    return [_to_out(c) for c in commandes]


@router.get("/{commande_id}", response_model=CommandeOut)
def obtenir_commande(commande_id: int):
    """Retourne le détail d'une commande par son ID."""
    return _to_out(_trouver(commande_id))


@router.put("/{commande_id}/decision", response_model=CommandeOut)
def decider_commande(commande_id: int, body: DecisionBody):
    """
    Le fournisseur accepte ou refuse une commande.

    Body JSON : {"action": "accepter"} ou {"action": "refuser"}

    Une commande acceptée sera incluse dans la prochaine optimisation.
    Une commande refusée est ignorée par l'algorithme NSGA-II.
    """
    _trouver(commande_id)  # vérifie existence

    if body.action == "accepter":
        result = app_state.gestionnaire.accepter(commande_id)
    else:
        result = app_state.gestionnaire.refuser(commande_id)

    if result is None:
        raise HTTPException(status_code=400,
            detail=f"Impossible de traiter la commande {commande_id} (déjà traitée ou introuvable).")

    # Invalider la solution actuelle : les routes devront être recalculées
    app_state.solution = None
    return _to_out(result)


@router.delete("/{commande_id}", status_code=204)
def supprimer_commande(commande_id: int):
    """Supprime une commande du système."""
    _trouver(commande_id)
    del app_state.gestionnaire.commandes[commande_id]
    app_state.solution = None


@router.post("/{commande_id}/ajouter-dynamique")
def ajouter_commande_dynamique(commande_id: int):
    """
    Insère une commande déjà acceptée dans la solution en cours,
    SANS relancer NSGA-II complet.

    Utilise l'algorithme 'cheapest insertion' :
    pour chaque conducteur et chaque position possible dans sa route,
    on choisit l'insertion qui augmente le moins la distance totale.

    Nécessite :
    - que la commande soit en statut 'acceptee'
    - qu'une solution existe déjà (avoir appelé POST /optimisation/lancer)
    """
    if app_state.solution is None:
        raise HTTPException(status_code=400,
            detail="Aucune solution en cours. Lancez d'abord POST /optimisation/lancer.")

    if not app_state.graph_ready:
        raise HTTPException(status_code=400,
            detail="Graphe non initialisé. Appelez POST /optimisation/init.")

    commande = _trouver(commande_id)
    if commande.statut != 'acceptee':
        raise HTTPException(status_code=400,
            detail=f"La commande {commande_id} doit être acceptée avant l'ajout dynamique.")

    commandes_acceptees = app_state.gestionnaire.get_acceptees()

    app_state.solution = vrp.ajouter_commande(
        app_state.solution,
        app_state.conducteurs,
        commandes_acceptees,
        commande
    )

    fit = vrp.evaluate(app_state.solution, app_state.conducteurs, commandes_acceptees)
    return {
        "message": f"Commande {commande_id} insérée dynamiquement.",
        "distance_totale_km": round(fit[0], 2),
        "desequilibre": round(fit[1], 2),
        "valide": vrp.is_valid(app_state.solution, app_state.conducteurs, commandes_acceptees)
    }


# ─── Helpers privés ──────────────────────────────────────────────────────────

def _trouver(commande_id: int) -> Commande:
    if commande_id not in app_state.gestionnaire.commandes:
        raise HTTPException(status_code=404, detail=f"Commande {commande_id} introuvable.")
    return app_state.gestionnaire.commandes[commande_id]


def _to_out(c: Commande) -> CommandeOut:
    return CommandeOut(
        id=c.id,
        lat=c.lat,
        lon=c.lon,
        demand=c.demand,
        description=c.description,
        statut=c.statut,
        x=c.x,
        y=c.y
    )