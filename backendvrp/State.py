from typing import Optional, Dict, List
from models import Conducteur, Commande, GestionnaireCommandes

REF_LAT = 36.7538
REF_LON  = 3.0588

class AppState:
    def __init__(self):
        self.conducteurs = []
        self.gestionnaire = GestionnaireCommandes()
        self.solution = None
        self.fitnesses = None
        self.graph_ready = False

    def reset(self):
        self.__init__()

app_state = AppState()