"""
routes/dashboard_routes.py — Endpoint tableau de bord

Retourne un résumé global de l'état du système,
utile pour une page d'accueil ou un écran de supervision.
"""

from fastapi import APIRouter
from Schemas import DashboardOut
from State import app_state

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/", response_model=DashboardOut, summary="Tableau de bord global")
def tableau_de_bord():
    """
    Retourne un résumé de l'état complet du système :
    - Nombre de conducteurs
    - Statistiques sur les commandes (total, acceptées, refusées, en attente)
    - Si une solution a été calculée
    - Si le graphe routier est prêt
    """
    g = app_state.gestionnaire
    total = len(g.commandes)
    acceptees = sum(1 for c in g.commandes.values() if c.statut == 'acceptee')
    refusees  = sum(1 for c in g.commandes.values() if c.statut == 'refusee')
    attente   = sum(1 for c in g.commandes.values() if c.statut == 'en_attente')

    return DashboardOut(
        nb_conducteurs=len(app_state.conducteurs),
        nb_commandes_total=total,
        nb_acceptees=acceptees,
        nb_refusees=refusees,
        nb_en_attente=attente,
        solution_calculee=app_state.solution is not None,
        graphe_pret=app_state.graph_ready
    )