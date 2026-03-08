import random
import math
from copy import deepcopy
from utils.distance import RoadGraph
from models import Commande, Conducteur, gps_to_xy

# =========================
# GRAPHE ROUTIER GLOBAL
# =========================

road_graph  = None
dist_matrix = None
REF_LAT     = None   # point de reference GPS pour la projection locale
REF_LON     = None


def init_road_graph(conducteurs, commandes, ref_lat, ref_lon,
                    num_nodes=30, use_osm=False, osm_place=None):
    """
    1. Definit le point de reference GPS
    2. Convertit les positions GPS en km locaux
    3. Construit le graphe (synthetique ou OSM selon use_osm)
    4. Mappe chaque point au noeud le plus proche
    5. Precalcule la matrice UNIQUEMENT sur les noeuds utiles (optimisation)

    Parametres :
        use_osm   : True = vraies routes OSM (pip install osmnx)
                    False = graphe synthetique (defaut)
        osm_place : ville si use_osm=True (ex: "Alger, Algerie")
    """
    global road_graph, dist_matrix, REF_LAT, REF_LON
    REF_LAT, REF_LON = ref_lat, ref_lon

    # Convertir positions GPS -> km locaux
    for c in conducteurs:
        c.x, c.y = gps_to_xy(c.lat, c.lon, REF_LAT, REF_LON)
    for cmd in commandes.values():
        cmd.x, cmd.y = gps_to_xy(cmd.lat, cmd.lon, REF_LAT, REF_LON)

    # Construire le graphe (OSM ou synthetique)
    road_graph = RoadGraph(use_osm=use_osm).build(
        num_nodes=num_nodes,
        place=osm_place or "Alger, Algerie"
    )

    # Mapper chaque point au noeud le plus proche
    for c in conducteurs:
        c.node_id = road_graph.snap_to_node(c.x, c.y)
        print(f"  {c.nom} GPS({c.lat},{c.lon}) -> noeud {c.node_id} "
              f"({c.x:.1f}, {c.y:.1f}) km")
    for cmd in commandes.values():
        cmd.node_id = road_graph.snap_to_node(cmd.x, cmd.y)
        print(f"  Commande {cmd.id} GPS({cmd.lat},{cmd.lon}) -> noeud {cmd.node_id} "
              f"({cmd.x:.1f}, {cmd.y:.1f}) km")

    # OPTIMISATION : matrice uniquement sur les noeuds utiles
    useful_nodes = set()
    for c in conducteurs:
        useful_nodes.add(c.node_id)
    for cmd in commandes.values():
        useful_nodes.add(cmd.node_id)
    print(f"  Noeuds utiles : {len(useful_nodes)} / {len(road_graph.nodes)} total")

    dist_matrix = road_graph.build_distance_matrix(
        useful_node_ids=list(useful_nodes)
    )


def update_conducteur_position(conducteur, new_lat, new_lon):
    """
    Met a jour la position GPS d'un conducteur en temps reel
    et recalcule son noeud dans le graphe.
    """
    conducteur.update_position(new_lat, new_lon)
    conducteur.x, conducteur.y = gps_to_xy(new_lat, new_lon, REF_LAT, REF_LON)
    conducteur.node_id = road_graph.snap_to_node(conducteur.x, conducteur.y)
    print(f"  Position mise a jour : {conducteur.nom} -> noeud {conducteur.node_id} "
          f"({conducteur.x:.1f}, {conducteur.y:.1f}) km")


# =========================
# DISTANCE (lookup O(1))
# Fonctionne avec Conducteur ou Commande (les deux ont node_id)
# =========================

def dist(a, b):
    return road_graph.get_distance(a.node_id, b.node_id)


# =========================
# EVALUATION
# Chaque conducteur part de SA position GPS, pas d'un depot fixe
# Il s'arrete a sa derniere livraison (pas de retour)
# =========================

def route_distance(route, commandes, conducteur):
    """
    Distance depuis la position actuelle du conducteur
    jusqu'au dernier client de sa route.
    Pas de retour au depot : le conducteur s'arrete au dernier client.
    """
    if not route:
        return 0
    total = 0
    prev = conducteur   # depart = position GPS du conducteur
    for cid in route:
        c = commandes[cid]
        total += dist(prev, c)
        prev = c
    return total


def route_load(route, commandes):
    return sum(commandes[c].demand for c in route)


def evaluate(solution, conducteurs, commandes):
    """
    Evalue une solution sur 2 objectifs :
    - distance totale (tous conducteurs)
    - desequilibre de charge
    """
    total_distance = 0
    loads = []
    for conducteur in conducteurs:
        route = solution[conducteur.id]
        total_distance += route_distance(route, commandes, conducteur)
        loads.append(route_load(route, commandes))
    imbalance = max(loads) - min(loads) if loads else 0
    return (total_distance, imbalance)


def is_valid(solution, conducteurs, commandes):
    all_served = []
    for conducteur in conducteurs:
        route = solution[conducteur.id]
        if route_load(route, commandes) > conducteur.capacity:
            return False
        all_served.extend(route)
    return sorted(all_served) == sorted(commandes.keys())


# =========================
# REPARATION
# =========================

def repair(solution, conducteurs, commandes):
    s = deepcopy(solution)
    all_ids = set(commandes.keys())

    # Supprimer les doublons
    seen = set()
    for tid in s:
        new_route = []
        for cid in s[tid]:
            if cid not in seen:
                seen.add(cid)
                new_route.append(cid)
        s[tid] = new_route

    # Reinserrer les manquants
    missing = list(all_ids - seen)
    random.shuffle(missing)
    for cid in missing:
        demand = commandes[cid].demand
        inserted = False
        for conducteur in conducteurs:
            if route_load(s[conducteur.id], commandes) + demand <= conducteur.capacity:
                s[conducteur.id].append(cid)
                inserted = True
                break
        if not inserted:
            lightest = min(conducteurs, key=lambda t: route_load(s[t.id], commandes))
            s[lightest.id].append(cid)

    # Corriger les depassements
    overflow = []
    for conducteur in conducteurs:
        if route_load(s[conducteur.id], commandes) > conducteur.capacity:
            overflow.extend(s[conducteur.id])
            s[conducteur.id] = []

    for cid in overflow:
        demand = commandes[cid].demand
        inserted = False
        for conducteur in sorted(conducteurs, key=lambda t: route_load(s[t.id], commandes)):
            if route_load(s[conducteur.id], commandes) + demand <= conducteur.capacity:
                s[conducteur.id].append(cid)
                inserted = True
                break
        if not inserted:
            lightest = min(conducteurs, key=lambda t: route_load(s[t.id], commandes))
            s[lightest.id].append(cid)

    return s


# =========================
# SOLUTION INITIALE
# =========================

def generate_solution(conducteurs, commandes):
    ids = list(commandes.keys())
    random.shuffle(ids)
    solution = {c.id: [] for c in conducteurs}
    loads    = {c.id: 0   for c in conducteurs}

    for cid in ids:
        demand   = commandes[cid].demand
        assigned = False
        shuffled = conducteurs[:]
        random.shuffle(shuffled)
        for conducteur in shuffled:
            if loads[conducteur.id] + demand <= conducteur.capacity:
                solution[conducteur.id].append(cid)
                loads[conducteur.id] += demand
                assigned = True
                break
        if not assigned:
            lightest = min(conducteurs, key=lambda t: loads[t.id])
            solution[lightest.id].append(cid)
            loads[lightest.id] += demand

    return solution


# =========================
# MUTATION
# =========================

def mutate(solution, conducteurs):
    s = deepcopy(solution)
    if random.random() < 0.5:
        t = random.choice(list(s.keys()))
        if len(s[t]) > 1:
            i, j = random.sample(range(len(s[t])), 2)
            s[t][i], s[t][j] = s[t][j], s[t][i]
    else:
        ids = [c.id for c in conducteurs]
        t1, t2 = random.sample(ids, 2)
        if len(s[t1]) > 0:
            idx = random.randrange(len(s[t1]))
            client = s[t1].pop(idx)
            s[t2].insert(random.randint(0, len(s[t2])), client)
    return s


# =========================
# CROSSOVER (Order Crossover)
# =========================

def crossover(p1, p2):
    order_p1 = [cid for tid in sorted(p1) for cid in p1[tid]]
    order_p2 = [cid for tid in sorted(p2) for cid in p2[tid]]
    n = len(order_p1)
    if n == 0:
        return deepcopy(p1)
    start, end = sorted(random.sample(range(n), 2))
    segment   = order_p1[start:end+1]
    remaining = [c for c in order_p2 if c not in segment]
    child_order = remaining[:start] + segment + remaining[start:]
    child, idx = {}, 0
    for tid in sorted(p1):
        size = len(p1[tid])
        child[tid] = child_order[idx:idx+size]
        idx += size
    return child


# =========================
# NSGA-II
# =========================

def dominates(a, b):
    return a[0] <= b[0] and a[1] <= b[1] and (a[0] < b[0] or a[1] < b[1])


def fast_non_dominated_sort(fitness_list):
    n = len(fitness_list)
    S  = [[] for _ in range(n)]
    dc = [0] * n
    fronts = [[]]
    for p in range(n):
        for q in range(n):
            if dominates(fitness_list[p], fitness_list[q]):
                S[p].append(q)
            elif dominates(fitness_list[q], fitness_list[p]):
                dc[p] += 1
        if dc[p] == 0:
            fronts[0].append(p)
    i = 0
    while fronts[i]:
        nf = []
        for p in fronts[i]:
            for q in S[p]:
                dc[q] -= 1
                if dc[q] == 0:
                    nf.append(q)
        i += 1
        fronts.append(nf)
    return fronts[:-1]


def crowding_distance(front, fitness_list):
    n = len(front)
    if n == 0:
        return []
    distances = [0.0] * n
    for obj in range(len(fitness_list[0])):
        sf = sorted(range(n), key=lambda i: fitness_list[front[i]][obj])
        distances[sf[0]] = distances[sf[-1]] = float('inf')
        f_min = fitness_list[front[sf[0]]][obj]
        f_max = fitness_list[front[sf[-1]]][obj]
        spread = f_max - f_min if f_max != f_min else 1e-9
        for k in range(1, n-1):
            distances[sf[k]] += (fitness_list[front[sf[k+1]]][obj] -
                                  fitness_list[front[sf[k-1]]][obj]) / spread
    return distances


def nsga2(conducteurs, commandes, pop_size=30, generations=80, seed=None):
    if seed is not None:
        random.seed(seed)

    population = [generate_solution(conducteurs, commandes) for _ in range(pop_size)]

    for _ in range(generations):
        offspring = []
        while len(offspring) < pop_size:
            p1 = random.choice(population)
            p2 = random.choice(population)
            child = crossover(p1, p2)
            if random.random() < 0.3:
                child = mutate(child, conducteurs)
            child = repair(child, conducteurs, commandes)
            offspring.append(child)

        combined     = population + offspring
        fitness_list = [evaluate(ind, conducteurs, commandes) for ind in combined]
        fronts       = fast_non_dominated_sort(fitness_list)

        new_population = []
        for front in fronts:
            if len(new_population) + len(front) <= pop_size:
                for idx in front:
                    new_population.append(combined[idx])
            else:
                remaining = pop_size - len(new_population)
                cd = crowding_distance(front, fitness_list)
                sf = sorted(range(len(front)), key=lambda i: cd[i], reverse=True)
                for i in sf[:remaining]:
                    new_population.append(combined[front[i]])
                break

        population = new_population

    return population, [evaluate(ind, conducteurs, commandes) for ind in population]


# =========================
# ROUTE DIRECTE (1 seule commande acceptee)
# Pas besoin de NSGA-II : on trouve juste le conducteur
# le plus proche de la commande
# =========================

def route_directe(conducteurs, commande):
    """
    Si le fournisseur n'a qu'une seule commande acceptee,
    on assigne simplement le conducteur le plus proche
    qui a assez de capacite.
    """
    candidats = [c for c in conducteurs if c.capacity >= commande.demand]
    if not candidats:
        candidats = conducteurs  # forcer si personne n'a la capacite

    meilleur = min(candidats, key=lambda c: dist(c, commande))
    solution = {c.id: [] for c in conducteurs}
    solution[meilleur.id] = [commande.id]

    distance = dist(meilleur, commande)
    print(f"  Route directe : {meilleur.nom} -> Commande {commande.id} "
          f"({distance:.2f} km)")
    return solution, meilleur, distance


# =========================
# AJOUT DYNAMIQUE D'UNE COMMANDE
# (commande acceptee en cours de route)
# =========================

def ajouter_commande(solution, conducteurs, commandes, nouvelle_commande):
    """
    Insere une nouvelle commande acceptee dans la solution en cours.
    Utilise le cheapest insertion depuis la position GPS de chaque conducteur.
    """
    # Mapper la nouvelle commande au graphe
    nouvelle_commande.x, nouvelle_commande.y = gps_to_xy(
        nouvelle_commande.lat, nouvelle_commande.lon, REF_LAT, REF_LON
    )
    nouvelle_commande.node_id = road_graph.snap_to_node(
        nouvelle_commande.x, nouvelle_commande.y
    )
    commandes[nouvelle_commande.id] = nouvelle_commande

    # Etendre la matrice de distances si ce noeud n'y est pas encore
    new_node = nouvelle_commande.node_id
    if road_graph._node_index is not None and new_node not in road_graph._node_index:
        all_useful = list(road_graph._node_index.keys()) + [new_node]
        road_graph.vider_cache()
        road_graph.build_distance_matrix(useful_node_ids=all_useful)
        print(f"  Matrice etendue pour noeud {new_node}")

    faisables = [
        c for c in conducteurs
        if route_load(solution[c.id], commandes) + nouvelle_commande.demand <= c.capacity
    ]
    if not faisables:
        print(f"  Aucun conducteur faisable, insertion forcee.")
        faisables = conducteurs

    best_conducteur = None
    best_pos        = 0
    best_increase   = float('inf')

    for conducteur in faisables:
        route = solution[conducteur.id]
        for i in range(len(route) + 1):
            new_route = route[:i] + [nouvelle_commande.id] + route[i:]
            # Recalculer distance avec la nouvelle commande inseree
            increase = (route_distance(new_route, commandes, conducteur)
                        - route_distance(route, commandes, conducteur))
            if increase < best_increase:
                best_increase   = increase
                best_pos        = i
                best_conducteur = conducteur

    solution[best_conducteur.id].insert(best_pos, nouvelle_commande.id)
    solution = repair(solution, conducteurs, commandes)
    print(f"  Commande {nouvelle_commande.id} inseree chez {best_conducteur.nom} "
          f"(position {best_pos}, +{best_increase:.2f} km)")
    return solution