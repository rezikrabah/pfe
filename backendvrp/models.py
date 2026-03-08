import math

# =========================
# COORDONNEES GPS
# Conversion latitude/longitude vers X/Y en km (projection simple)
# =========================

EARTH_RADIUS_KM = 6371.0

def gps_to_xy(lat, lon, ref_lat, ref_lon):
    """
    Convertit des coordonnees GPS (lat, lon) en coordonnees locales (x, y) en km
    par rapport a un point de reference (ref_lat, ref_lon).
    """
    x = math.radians(lon - ref_lon) * math.cos(math.radians(ref_lat)) * EARTH_RADIUS_KM
    y = math.radians(lat - ref_lat) * EARTH_RADIUS_KM
    return round(x, 4), round(y, 4)


# =========================
# COMMANDE (remplace Client)
# Une commande peut etre en_attente, acceptee ou refusee
# =========================

class Commande:
    def __init__(self, cid, lat, lon, demand, description=""):
        self.id       = cid
        self.lat      = lat
        self.lon      = lon
        self.demand   = demand
        self.description = description
        self.statut   = 'en_attente'   # 'en_attente' | 'acceptee' | 'refusee'
        self.x        = None           # coordonnee locale (calculee apres init)
        self.y        = None
        self.node_id  = None           # noeud du graphe routier

    def __repr__(self):
        return (f"Commande(id={self.id}, lat={self.lat}, lon={self.lon}, "
                f"demande={self.demand}, statut={self.statut})")


# =========================
# CONDUCTEUR (remplace Truck + Depot)
# Chaque conducteur a sa propre position GPS en temps reel
# =========================

class Conducteur:
    def __init__(self, tid, capacity, lat, lon, nom=""):
        self.id       = tid
        self.capacity = capacity
        self.lat      = lat       # position GPS actuelle (geolocalisation)
        self.lon      = lon
        self.nom      = nom or f"Conducteur {tid}"
        self.x        = None      # coordonnee locale (calculee apres init)
        self.y        = None
        self.node_id  = None      # noeud du graphe routier

    def update_position(self, lat, lon):
        """Met a jour la position GPS du conducteur (appel geolocalisation)."""
        self.lat = lat
        self.lon = lon
        # x, y et node_id seront recalcules par init_road_graph

    def __repr__(self):
        return f"Conducteur(id={self.id}, nom={self.nom}, pos=({self.lat},{self.lon}), cap={self.capacity})"


# =========================
# GESTIONNAIRE DE COMMANDES
# Gere l'acceptation/refus par le fournisseur
# =========================

class GestionnaireCommandes:

    def __init__(self):
        self.commandes = {}   # {cid: Commande}

    def ajouter(self, commande):
        """Ajoute une nouvelle commande en attente."""
        self.commandes[commande.id] = commande
        print(f"  [+] Nouvelle commande recue : {commande.id} "
              f"({commande.description}, demande={commande.demand})")

    def accepter(self, cid):
        """Le fournisseur accepte une commande."""
        if cid not in self.commandes:
            print(f"  [!] Commande {cid} introuvable.")
            return None
        c = self.commandes[cid]
        if c.statut != 'en_attente':
            print(f"  [!] Commande {cid} deja traitee (statut: {c.statut}).")
            return None
        c.statut = 'acceptee'
        print(f"  [OK] Commande {cid} ACCEPTEE ({c.description})")
        return c

    def refuser(self, cid):
        """Le fournisseur refuse une commande."""
        if cid not in self.commandes:
            print(f"  [!] Commande {cid} introuvable.")
            return None
        c = self.commandes[cid]
        c.statut = 'refusee'
        print(f"  [X]  Commande {cid} REFUSEE ({c.description})")
        return c

    def get_acceptees(self):
        """Retourne uniquement les commandes acceptees."""
        return {cid: c for cid, c in self.commandes.items()
                if c.statut == 'acceptee'}

    def get_en_attente(self):
        return {cid: c for cid, c in self.commandes.items()
                if c.statut == 'en_attente'}

    def resume(self):
        total    = len(self.commandes)
        acceptes = sum(1 for c in self.commandes.values() if c.statut == 'acceptee')
        refuses  = sum(1 for c in self.commandes.values() if c.statut == 'refusee')
        attente  = sum(1 for c in self.commandes.values() if c.statut == 'en_attente')
        print(f"\n  Commandes : {total} total | "
              f"{acceptes} acceptees | {refuses} refusees | {attente} en attente")
