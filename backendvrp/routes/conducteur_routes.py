from typing import List
"""
routes/conducteur_routes.py — Endpoints pour gérer les conducteurs

Un "router" FastAPI est un mini-groupe d'endpoints qu'on branche
sur l'application principale dans app.py.

Endpoints disponibles :
  POST   /conducteurs/          → ajouter un conducteur
  GET    /conducteurs/          → lister tous les conducteurs
  GET    /conducteurs/{id}      → détail d'un conducteur
  DELETE /conducteurs/{id}      → supprimer un conducteur
  PUT    /conducteurs/{id}/position → mettre à jour sa position GPS
"""

from fastapi import APIRouter, HTTPException
from Schemas import ConducteurCreate, ConducteurOut, ConducteurPositionUpdate
from models import Conducteur
from State import app_state
import vrp_nsga2 as vrp

router = APIRouter(prefix="/conducteurs", tags=["Conducteurs"])


@router.post("/", response_model=ConducteurOut, status_code=201)
def ajouter_conducteur(data: ConducteurCreate):
    """
    Crée un nouveau conducteur et l'ajoute à l'état global.

    - Vérifie que l'ID n'existe pas déjà.
    - Le conducteur n'a pas encore de coordonnées locales (x, y)
      car le graphe routier n'est peut-être pas encore initialisé.
    """
    # Vérifier les doublons
    if any(c.id == data.id for c in app_state.conducteurs):
        raise HTTPException(status_code=409, detail=f"Conducteur {data.id} existe déjà.")

    conducteur = Conducteur(
        tid=data.id,
        capacity=data.capacity,
        lat=data.lat,
        lon=data.lon,
        nom=data.nom or f"Conducteur {data.id}"
    )
    app_state.conducteurs.append(conducteur)

    # Marquer le graphe comme non prêt (il faut réinitialiser après ajout)
    app_state.graph_ready = False

    return _to_out(conducteur)


@router.get("/", response_model=List[ConducteurOut])
def lister_conducteurs():
    """Retourne la liste de tous les conducteurs enregistrés."""
    return [_to_out(c) for c in app_state.conducteurs]


@router.get("/{conducteur_id}", response_model=ConducteurOut)
def obtenir_conducteur(conducteur_id: int):
    """Retourne les détails d'un conducteur par son ID."""
    conducteur = _trouver(conducteur_id)
    return _to_out(conducteur)


@router.delete("/{conducteur_id}", status_code=204)
def supprimer_conducteur(conducteur_id: int):
    """
    Supprime un conducteur.
    Invalide aussi la solution courante si elle existe.
    """
    conducteur = _trouver(conducteur_id)
    app_state.conducteurs.remove(conducteur)
    app_state.solution = None   # la solution n'est plus valide
    app_state.graph_ready = False


@router.put("/{conducteur_id}/position", response_model=ConducteurOut)
def mettre_a_jour_position(conducteur_id: int, body: ConducteurPositionUpdate):
    """
    Met à jour la position GPS d'un conducteur en temps réel.

    Simule la géolocalisation : le camion a bougé,
    on recalcule son nœud dans le graphe routier.
    Nécessite que le graphe soit initialisé (appeler POST /optimisation/init d'abord).
    """
    if not app_state.graph_ready:
        raise HTTPException(
            status_code=400,
            detail="Le graphe routier n'est pas initialisé. Appelez POST /optimisation/init d'abord."
        )

    conducteur = _trouver(conducteur_id)
    vrp.update_conducteur_position(conducteur, body.lat, body.lon)
    return _to_out(conducteur)


# ─── Helpers privés ──────────────────────────────────────────────────────────

def _trouver(conducteur_id: int) -> Conducteur:
    """Cherche un conducteur par ID ou lève une 404."""
    for c in app_state.conducteurs:
        if c.id == conducteur_id:
            return c
    raise HTTPException(status_code=404, detail=f"Conducteur {conducteur_id} introuvable.")


def _to_out(c: Conducteur) -> ConducteurOut:
    """Convertit un objet Conducteur en schéma de réponse."""
    return ConducteurOut(
        id=c.id,
        capacity=c.capacity,
        lat=c.lat,
        lon=c.lon,
        nom=c.nom,
        x=c.x,
        y=c.y,
        node_id=c.node_id
    )