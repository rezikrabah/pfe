"""
schemas.py — Modeles Pydantic pour la validation des donnees
Compatible avec Pydantic v2 + Python 3.14
"""

from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List


# ─────────────────────────────────────────────
# CONDUCTEURS
# ─────────────────────────────────────────────

class ConducteurCreate(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "id": 1,
                "capacity": 400,
                "lat": 36.7600,
                "lon": 3.0500,
                "nom": "Conducteur A"
            }
        }
    )

    id: int
    capacity: int = Field(..., gt=0, description="Capacite maximale en litres")
    lat: float = Field(..., description="Latitude GPS actuelle")
    lon: float = Field(..., description="Longitude GPS actuelle")
    nom: Optional[str] = None


class ConducteurOut(BaseModel):
    id: int
    capacity: int
    lat: float
    lon: float
    nom: str
    x: Optional[float] = None
    y: Optional[float] = None
    node_id: Optional[int] = None


class ConducteurPositionUpdate(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {"lat": 36.7650, "lon": 3.0520}
        }
    )

    lat: float
    lon: float


# ─────────────────────────────────────────────
# COMMANDES
# ─────────────────────────────────────────────

class CommandeCreate(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "id": 1,
                "lat": 36.7620,
                "lon": 3.0450,
                "demand": 80,
                "description": "Client Bab El Oued"
            }
        }
    )

    id: int
    lat: float
    lon: float
    demand: int = Field(..., gt=0, description="Volume d'eau demande en litres")
    description: Optional[str] = ""


class CommandeOut(BaseModel):
    id: int
    lat: float
    lon: float
    demand: int
    description: str
    statut: str
    x: Optional[float] = None
    y: Optional[float] = None


class DecisionBody(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {"action": "accepter"}
        }
    )

    action: str = Field(
        ...,
        pattern="^(accepter|refuser)$",
        description="'accepter' ou 'refuser'"
    )


# ─────────────────────────────────────────────
# OPTIMISATION
# ─────────────────────────────────────────────

class OptimisationParams(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {"pop_size": 30, "generations": 80, "seed": 42}
        }
    )

    pop_size: int = Field(30, ge=10, le=200, description="Taille de la population")
    generations: int = Field(80, ge=10, le=500, description="Nombre de generations")
    seed: Optional[int] = None


class RouteInfo(BaseModel):
    conducteur_id: int
    conducteur_nom: str
    route: List[int]
    charge: int
    capacite: int
    distance_km: float


class SolutionOut(BaseModel):
    routes: List[RouteInfo]
    distance_totale_km: float
    desequilibre: float
    valide: bool
    nb_commandes: int


class ParetoPoint(BaseModel):
    distance_km: float
    desequilibre: float


# ─────────────────────────────────────────────
# DASHBOARD
# ─────────────────────────────────────────────

class DashboardOut(BaseModel):
    nb_conducteurs: int
    nb_commandes_total: int
    nb_acceptees: int
    nb_refusees: int
    nb_en_attente: int
    solution_calculee: bool
    graphe_pret: bool