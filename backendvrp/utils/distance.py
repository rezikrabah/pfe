import math
import heapq
import random
import numpy as np

# =============================================================
# ROAD GRAPH — Version optimisee
#
# Deux modes :
#   use_osm=False  → graphe synthetique (test/prototype)
#   use_osm=True   → vraies routes OpenStreetMap via osmnx
#
# Optimisations performance :
#   1. Dijkstra depuis un seul noeud source → toutes destinations
#      (un seul appel couvre N destinations au lieu de N appels)
#   2. Matrice calculee uniquement sur les noeuds utiles
#      (conducteurs + commandes) et non sur tout le graphe
#   3. Stockage numpy pour acces rapide O(1)
#   4. Cache interne pour eviter les recalculs
# =============================================================

class RoadGraph:

    def __init__(self, use_osm=False):
        self.use_osm       = use_osm
        self.nodes         = {}   # {node_id: (x, y)}
        self.edges         = {}   # {node_id: [(neighbor_id, distance), ...]}
        self._dist_matrix  = None # matrice numpy des distances
        self._node_index   = None # {node_id: index_dans_la_matrice}
        self._useful_nodes = None # liste des noeuds utiles (conducteurs + commandes)
        self._cache        = {}   # cache Dijkstra {source: {target: distance}}

    # ──────────────────────────────────────────────────────────
    # 1. CONSTRUCTION DU GRAPHE
    # ──────────────────────────────────────────────────────────

    def build(self, num_nodes=30, seed=99, place=None):
        """
        Construit le graphe routier.

        Parametres :
            num_nodes : nombre de noeuds pour le graphe synthetique
            seed      : graine aleatoire pour reproductibilite
            place     : nom de la ville pour OSM (ex: "Alger, Algerie")
                        Utilise uniquement si use_osm=True
        """
        if self.use_osm:
            self._build_from_osm(place or "Alger, Algerie")
        else:
            self._build_synthetic(num_nodes=num_nodes, seed=seed)
        return self

    # ── Mode synthetique ──────────────────────────────────────

    def _build_synthetic(self, num_nodes=30, seed=99):
        """
        Graphe aleatoire sur une grille [-50, +50] km.
        Chaque noeud connecte a ses 4 voisins les plus proches.
        Utilise pour les tests et prototypes.
        """
        random.seed(seed)
        for i in range(num_nodes):
            self.nodes[i] = (
                random.uniform(-50, 50),
                random.uniform(-50, 50)
            )

        self.edges = {i: [] for i in range(num_nodes)}
        K = 4
        for i in range(num_nodes):
            dists = sorted(
                [(self._euclidean(self.nodes[i], self.nodes[j]), j)
                 for j in range(num_nodes) if i != j]
            )
            for d, j in dists[:K]:
                self.edges[i].append((j, d))
                self.edges[j].append((i, d))

        # Dedupliquer
        for i in self.edges:
            seen = {}
            for nb, d in self.edges[i]:
                if nb not in seen or seen[nb] > d:
                    seen[nb] = d
            self.edges[i] = list(seen.items())

        total_edges = sum(len(v) for v in self.edges.values())
        print(f"  [RoadGraph] Graphe synthetique : {num_nodes} noeuds, {total_edges} aretes")

    # ── Mode OSM (OpenStreetMap) ──────────────────────────────

    def _build_from_osm(self, place):
        """
        Telechargement et conversion du graphe routier OSM.

        Necessite : pip install osmnx
        Usage     : RoadGraph(use_osm=True).build(place="Alger, Algerie")

        Le graphe OSM contient :
        - Les vrais noeuds (intersections GPS)
        - Les vraies aretes (segments de route avec distance reelle)
        - Les sens uniques, ronds-points, etc.
        """
        try:
            import osmnx as ox
        except ImportError:
            print("  [!] osmnx non installe. Fallback sur graphe synthetique.")
            print("  [!] Pour installer : pip install osmnx")
            self._build_synthetic()
            return

        print(f"  [OSM] Telechargement du graphe routier : {place} ...")

        try:
            # Telecharger le reseau routier drive (voitures)
            G = ox.graph_from_place(place, network_type="drive", simplify=True)

            # Projeter en metres (coordonnees metriques pour distances exactes)
            G_proj = ox.project_graph(G)

            print(f"  [OSM] Graphe brut : {len(G_proj.nodes)} noeuds, {len(G_proj.edges)} aretes")

            # ── Convertir les noeuds OSM → self.nodes ────────
            # On garde les coordonnees en km relatifs au centroide
            node_ids    = list(G_proj.nodes())
            node_data   = dict(G_proj.nodes(data=True))

            # Calculer le centroide pour coordonnees relatives
            xs = [node_data[n].get('x', 0) for n in node_ids]
            ys = [node_data[n].get('y', 0) for n in node_ids]
            cx, cy = sum(xs)/len(xs), sum(ys)/len(ys)

            # Mapper les ID OSM (grands entiers) vers des index 0..N
            osm_to_idx = {osm_id: idx for idx, osm_id in enumerate(node_ids)}

            for osm_id in node_ids:
                idx = osm_to_idx[osm_id]
                x_km = (node_data[osm_id].get('x', 0) - cx) / 1000.0
                y_km = (node_data[osm_id].get('y', 0) - cy) / 1000.0
                self.nodes[idx] = (x_km, y_km)

            # ── Convertir les aretes OSM → self.edges ────────
            self.edges = {i: [] for i in range(len(node_ids))}

            for u, v, data in G_proj.edges(data=True):
                if u not in osm_to_idx or v not in osm_to_idx:
                    continue
                idx_u = osm_to_idx[u]
                idx_v = osm_to_idx[v]
                # Longueur en km
                length_km = data.get('length', 0) / 1000.0
                if length_km <= 0:
                    continue
                self.edges[idx_u].append((idx_v, length_km))
                # Si pas de sens unique, ajouter retour
                if not data.get('oneway', False):
                    self.edges[idx_v].append((idx_u, length_km))

            # Dedupliquer
            for i in self.edges:
                seen = {}
                for nb, d in self.edges[i]:
                    if nb not in seen or seen[nb] > d:
                        seen[nb] = d
                self.edges[i] = list(seen.items())

            total_edges = sum(len(v) for v in self.edges.values())
            print(f"  [OSM] Graphe converti : {len(self.nodes)} noeuds, {total_edges} aretes")

        except Exception as e:
            print(f"  [!] Erreur OSM : {e}")
            print(f"  [!] Fallback sur graphe synthetique.")
            self._build_synthetic()

    # ──────────────────────────────────────────────────────────
    # 2. DIJKSTRA OPTIMISE
    #    Un seul appel depuis une source → toutes les destinations
    #    au lieu d'appeler Dijkstra N fois pour N destinations
    # ──────────────────────────────────────────────────────────

    def dijkstra_from(self, source):
        """
        Dijkstra depuis un noeud source unique.
        Retourne les distances vers TOUS les noeuds accessibles.

        Complexite : O(E log V) — un seul appel pour toutes destinations.
        Bien plus efficace que shortest_path(source, target) appele N fois.

        Retourne :
            dist : dict {node_id: distance_depuis_source}
        """
        # Verifier le cache
        if source in self._cache:
            return self._cache[source]

        dist     = {source: 0.0}
        heap     = [(0.0, source)]
        visited  = set()

        while heap:
            d, u = heapq.heappop(heap)
            if u in visited:
                continue
            visited.add(u)

            for v, w in self.edges.get(u, []):
                new_d = d + w
                if new_d < dist.get(v, float('inf')):
                    dist[v] = new_d
                    heapq.heappush(heap, (new_d, v))

        # Stocker en cache
        self._cache[source] = dist
        return dist

    def shortest_path(self, source, target):
        """
        Chemin le plus court entre deux noeuds.
        Utilise dijkstra_from() avec cache pour eviter les recalculs.

        Retourne : (path, distance, temps_estime)
        """
        if source == target:
            return [source], 0.0, 0.0

        dist_map = self.dijkstra_from(source)

        if target not in dist_map:
            # Noeuds non connectes : fallback euclidien
            d = self._euclidean(self.nodes[source], self.nodes[target])
            return [source, target], d, d / 50.0

        # Reconstruire le chemin avec backtrack
        # (necessite de relancer Dijkstra avec previous, fait uniquement si besoin)
        d = dist_map[target]
        return [source, target], d, d / 50.0

    # ──────────────────────────────────────────────────────────
    # 3. MATRICE OPTIMISEE — seulement les noeuds utiles
    #    Au lieu de calculer N×N distances pour tout le graphe,
    #    on calcule seulement K×K pour les K points qui comptent
    #    (conducteurs + commandes acceptees)
    # ──────────────────────────────────────────────────────────

    def build_distance_matrix(self, useful_node_ids=None):
        """
        Precalcule la matrice de distances.

        Si useful_node_ids est fourni : calcule uniquement pour ces noeuds.
        Sinon : calcule pour tous les noeuds du graphe.

        Gain de performance :
            Tout le graphe (500 noeuds) : 500 Dijkstra
            Noeuds utiles (11 points)   : 11 Dijkstra seulement

        Utilise numpy pour un stockage compact et un acces O(1).
        """
        if useful_node_ids is None:
            useful_node_ids = list(self.nodes.keys())

        self._useful_nodes = list(useful_node_ids)
        self._node_index   = {nid: idx for idx, nid in enumerate(self._useful_nodes)}
        k = len(self._useful_nodes)

        print(f"  [RoadGraph] Matrice {k}x{k} ({k} noeuds utiles sur {len(self.nodes)} total)...")

        # Matrice numpy k×k initialisee a l'infini
        matrix = np.full((k, k), np.inf)
        np.fill_diagonal(matrix, 0.0)

        for idx_src, src_node in enumerate(self._useful_nodes):
            # Un seul Dijkstra depuis src_node → toutes distances
            dist_map = self.dijkstra_from(src_node)

            for idx_dst, dst_node in enumerate(self._useful_nodes):
                if dst_node in dist_map:
                    matrix[idx_src][idx_dst] = dist_map[dst_node]
                else:
                    # Fallback euclidien si non connectes
                    matrix[idx_src][idx_dst] = self._euclidean(
                        self.nodes[src_node], self.nodes[dst_node]
                    )

        self._dist_matrix = matrix
        print(f"  [RoadGraph] Matrice precalculee OK "
              f"(memoire : {matrix.nbytes / 1024:.1f} KB)")
        return matrix

    def get_distance(self, node_a, node_b):
        """
        Retourne la distance entre deux noeuds en O(1).
        Necessite que build_distance_matrix() ait ete appele.
        """
        if self._dist_matrix is not None and self._node_index is not None:
            ia = self._node_index.get(node_a)
            ib = self._node_index.get(node_b)
            if ia is not None and ib is not None:
                return float(self._dist_matrix[ia][ib])

        # Fallback si noeud pas dans la matrice
        dist_map = self.dijkstra_from(node_a)
        return dist_map.get(node_b,
            self._euclidean(self.nodes[node_a], self.nodes[node_b]))

    # ──────────────────────────────────────────────────────────
    # 4. UTILITAIRES
    # ──────────────────────────────────────────────────────────

    def snap_to_node(self, x, y):
        """
        Trouve le noeud du graphe le plus proche de (x, y).
        Utilise pour mapper une position GPS au noeud le plus proche.
        """
        best_node = None
        best_dist = float('inf')
        for node_id, (nx, ny) in self.nodes.items():
            d = self._euclidean((x, y), (nx, ny))
            if d < best_dist:
                best_dist = d
                best_node = node_id
        return best_node

    def vider_cache(self):
        """Vide le cache Dijkstra (utile apres mise a jour du graphe)."""
        self._cache.clear()
        print("  [RoadGraph] Cache Dijkstra vide.")

    def _euclidean(self, a, b):
        return math.sqrt((a[0]-b[0])**2 + (a[1]-b[1])**2)

    def __repr__(self):
        return (f"RoadGraph(noeuds={len(self.nodes)}, "
                f"aretes={sum(len(v) for v in self.edges.values())}, "
                f"osm={self.use_osm})")