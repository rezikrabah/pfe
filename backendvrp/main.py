import random
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

from models import Commande, Conducteur, GestionnaireCommandes, gps_to_xy
from vrp_nsga2 import (
    init_road_graph, update_conducteur_position,
    route_load, evaluate, is_valid,
    nsga2, route_directe, ajouter_commande
)

# =========================
# POINT DE REFERENCE GPS
# Centre de la zone de livraison (ex: Alger centre)
# =========================
REF_LAT = 36.7538
REF_LON = 3.0588


# =========================
# VISUALISATION
# =========================

def plot_solution(solution, conducteurs, commandes, title="", filename="map.png", nouvelle=None):
    colors = ['#2196F3', '#4CAF50', '#9C27B0', '#FF5722', '#00BCD4']
    fig, ax = plt.subplots(figsize=(13, 10))
    ax.set_facecolor('#F0F4F8')
    fig.patch.set_facecolor('#FFFFFF')
    ax.grid(True, alpha=0.3, color='#CCCCCC', linestyle='--')

    legend_handles = []

    for idx, conducteur in enumerate(conducteurs):
        route = solution[conducteur.id]
        color = colors[idx % len(colors)]

        # Dessiner position du conducteur
        ax.scatter(conducteur.x, conducteur.y, c=color, s=200, zorder=6,
                   marker='^', edgecolors='white', linewidths=2)
        ax.annotate(f" {conducteur.nom}\n GPS: ({conducteur.lat:.4f},{conducteur.lon:.4f})",
                    (conducteur.x, conducteur.y),
                    fontsize=7, color=color, fontweight='bold', zorder=7)

        if not route:
            continue

        # Dessiner la route depuis la position du conducteur
        points = [(conducteur.x, conducteur.y)]
        for cid in route:
            points.append((commandes[cid].x, commandes[cid].y))

        for i in range(len(points) - 1):
            ax.annotate("",
                xy=(points[i+1][0], points[i+1][1]),
                xytext=(points[i][0], points[i][1]),
                arrowprops=dict(arrowstyle="-|>", color=color, lw=2.0,
                                connectionstyle="arc3,rad=0.05"))

        load = route_load(route, commandes)
        patch = mpatches.Patch(color=color,
            label=f"{conducteur.nom}  |  Route: {route}  |  Charge: {load}/{conducteur.capacity}")
        legend_handles.append(patch)

    # Dessiner les commandes
    for cid, cmd in commandes.items():
        is_new = nouvelle and cid == nouvelle.id
        color_pt = '#FF9800' if is_new else '#1565C0'
        marker   = 'D' if is_new else 'o'
        ax.scatter(cmd.x, cmd.y, c=color_pt, s=100, zorder=5,
                   marker=marker, edgecolors='white', linewidths=1.5)
        ax.annotate(f" C{cid}\n{cmd.demand}",
                    (cmd.x, cmd.y), fontsize=8, color='#212121',
                    fontweight='bold', zorder=6)

    if nouvelle:
        legend_handles.append(mpatches.Patch(color='#FF9800',
            label=f"Nouvelle commande C{nouvelle.id} (ajout dynamique)"))

    ax.set_title(title, fontsize=13, fontweight='bold', pad=12)
    ax.set_xlabel("X (km depuis reference)", fontsize=10)
    ax.set_ylabel("Y (km depuis reference)", fontsize=10)
    ax.legend(handles=legend_handles, loc='upper left',
              fontsize=8, framealpha=0.9)

    plt.tight_layout()
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"  Carte sauvegardee : {filename}")


def plot_pareto(fitnesses, filename="map_pareto.png"):
    pareto = set()
    for i, fi in enumerate(fitnesses):
        dominated = any(
            fj[0] <= fi[0] and fj[1] <= fi[1] and (fj[0] < fi[0] or fj[1] < fi[1])
            for j, fj in enumerate(fitnesses) if i != j
        )
        if not dominated:
            pareto.add((round(fi[0], 2), round(fi[1], 2)))

    fig, ax = plt.subplots(figsize=(8, 6))
    ax.set_facecolor('#F5F5F5')
    ds  = [d for d, _ in sorted(pareto)]
    ims = [i for _, i in sorted(pareto)]
    ax.plot(ds, ims, 'o-', color='#2196F3', lw=2, markersize=8,
            markerfacecolor='#F44336', markeredgecolor='white', markeredgewidth=1.5)
    for d, im in zip(ds, ims):
        ax.annotate(f"({d:.0f}, {im:.0f})", (d, im),
                    textcoords="offset points", xytext=(8, 5), fontsize=8)
    ax.set_xlabel("Distance totale (km)", fontsize=11)
    ax.set_ylabel("Desequilibre de charge", fontsize=11)
    ax.set_title("Front de Pareto", fontsize=13, fontweight='bold')
    ax.grid(True, alpha=0.3, linestyle='--')
    plt.tight_layout()
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"  Carte Pareto sauvegardee : {filename}")


# =========================
# MAIN
# =========================

def main():

    # ─── ETAPE 1 : Creer les conducteurs avec leur position GPS reelle ────
    print("=" * 60)
    print("ETAPE 1 : Conducteurs (position GPS reelle)")
    print("=" * 60)

    conducteurs = [
        Conducteur(1, capacity=400, lat=36.7600, lon=3.0500, nom="Conducteur A"),
        Conducteur(2, capacity=400, lat=36.7450, lon=3.0700, nom="Conducteur B"),
        Conducteur(3, capacity=400, lat=36.7580, lon=3.0800, nom="Conducteur C"),
    ]
    for c in conducteurs:
        print(f"  {c.nom} : GPS ({c.lat}, {c.lon}), capacite={c.capacity}")


    # ─── ETAPE 2 : Creer les commandes ───────────────────────────────────
    print("\n" + "=" * 60)
    print("ETAPE 2 : Commandes recues")
    print("=" * 60)

    gestionnaire = GestionnaireCommandes()
    random.seed(42)

    commandes_data = [
        (1,  36.7620, 3.0450, 80,  "Client Bab El Oued"),
        (2,  36.7480, 3.0600, 120, "Client Hussein Dey"),
        (3,  36.7550, 3.0750, 90,  "Client El Harrach"),
        (4,  36.7400, 3.0500, 150, "Client Kouba"),
        (5,  36.7700, 3.0650, 60,  "Client Rouiba"),
        (6,  36.7500, 3.0850, 110, "Client Baraki"),
        (7,  36.7630, 3.0350, 75,  "Client Birkhadem"),
        (8,  36.7350, 3.0700, 130, "Client Draria"),
        (9,  36.7580, 3.0950, 95,  "Client Ain Naadja"),
        (10, 36.7450, 3.0400, 70,  "Client Cheraga"),
    ]
    for cid, lat, lon, demand, desc in commandes_data:
        gestionnaire.ajouter(Commande(cid, lat, lon, demand, desc))


    # ─── ETAPE 3 : Le fournisseur accepte ou refuse chaque commande ───────
    print("\n" + "=" * 60)
    print("ETAPE 3 : Decision du fournisseur")
    print("=" * 60)

    # Simulation : le fournisseur accepte certaines commandes et en refuse d'autres
    gestionnaire.accepter(1)
    gestionnaire.accepter(2)
    gestionnaire.accepter(3)
    gestionnaire.refuser(4)    # refuse
    gestionnaire.accepter(5)
    gestionnaire.accepter(6)
    gestionnaire.refuser(7)    # refuse
    gestionnaire.accepter(8)
    gestionnaire.accepter(9)
    gestionnaire.accepter(10)

    gestionnaire.resume()
    commandes_acceptees = gestionnaire.get_acceptees()
    print(f"\n  Commandes a livrer : {list(commandes_acceptees.keys())}")


    # ─── ETAPE 4 : Initialiser le graphe routier ─────────────────────────
    print("\n" + "=" * 60)
    print("ETAPE 4 : Construction du graphe routier (GPS -> km)")
    print("=" * 60)
    init_road_graph(conducteurs, commandes_acceptees, REF_LAT, REF_LON, num_nodes=30)


    # ─── ETAPE 5 : Choisir le bon mode selon le nombre de commandes ───────
    print("\n" + "=" * 60)
    print("ETAPE 5 : Optimisation des routes")
    print("=" * 60)

    nb = len(commandes_acceptees)

    if nb == 0:
        print("  Aucune commande acceptee. Rien a livrer.")
        return

    elif nb == 1:
        # ── CAS 1 COMMANDE : route directe, pas besoin de NSGA-II ──
        print(f"  1 seule commande acceptee -> route directe")
        cid_unique = list(commandes_acceptees.keys())[0]
        cmd_unique = commandes_acceptees[cid_unique]
        solution, meilleur_conducteur, distance = route_directe(conducteurs, cmd_unique)

        print(f"\n  {meilleur_conducteur.nom} livre la commande {cid_unique}")
        print(f"  Distance : {distance:.2f} km")
        print(f"  Solution valide : {is_valid(solution, conducteurs, commandes_acceptees)}")

        plot_solution(solution, conducteurs, commandes_acceptees,
                      title=f"Route directe | Commande {cid_unique} | {distance:.2f} km",
                      filename="map_route_directe.png")

    else:
        # ── CAS PLUSIEURS COMMANDES : NSGA-II ──
        print(f"  {nb} commandes acceptees -> optimisation NSGA-II")
        solutions, fitnesses = nsga2(conducteurs, commandes_acceptees, seed=0)

        best_idx = min(range(len(fitnesses)), key=lambda i: fitnesses[i][0])
        best     = solutions[best_idx]
        best_fit = fitnesses[best_idx]

        print("\n  Meilleure solution :")
        for c in conducteurs:
            route = best[c.id]
            load  = route_load(route, commandes_acceptees)
            print(f"  {c.nom} | Route: {route} | Charge: {load}/{c.capacity}")
        print(f"\n  Distance totale : {best_fit[0]:.2f} km")
        print(f"  Desequilibre    : {best_fit[1]:.2f}")
        print(f"  Solution valide : {is_valid(best, conducteurs, commandes_acceptees)}")

        plot_solution(best, conducteurs, commandes_acceptees,
                      title=f"Routes optimisees | Distance: {best_fit[0]:.2f} km | Desequilibre: {best_fit[1]:.0f}",
                      filename="map_initial.png")
        plot_pareto(fitnesses, filename="map_pareto.png")


        # ─── ETAPE 6 : Mise a jour GPS + nouvelle commande dynamique ─────
        print("\n" + "=" * 60)
        print("ETAPE 6 : Simulation temps reel")
        print("=" * 60)

        # 6a. Un conducteur s'est deplace
        print("\n  [GPS] Mise a jour position Conducteur A...")
        update_conducteur_position(conducteurs[0], new_lat=36.7650, new_lon=3.0520)

        # 6b. Nouvelle commande acceptee dynamiquement
        print("\n  [COMMANDE] Nouvelle commande recue...")
        nouvelle = Commande(11, 36.7520, 3.0680, 85, "Client Sidi M'hamed")
        gestionnaire.ajouter(nouvelle)
        gestionnaire.accepter(11)

        best = ajouter_commande(best, conducteurs, commandes_acceptees, nouvelle)

        print("\n  Routes apres ajout :")
        for c in conducteurs:
            route = best[c.id]
            load  = route_load(route, commandes_acceptees)
            print(f"  {c.nom} | Route: {route} | Charge: {load}/{c.capacity}")

        fit_after = evaluate(best, conducteurs, commandes_acceptees)
        print(f"\n  Distance totale : {fit_after[0]:.2f} km")
        print(f"  Solution valide : {is_valid(best, conducteurs, commandes_acceptees)}")

        plot_solution(best, conducteurs, commandes_acceptees,
                      title=f"Apres ajout commande 11 | Distance: {fit_after[0]:.2f} km",
                      filename="map_apres_ajout.png",
                      nouvelle=nouvelle)

        print("\n" + "=" * 60)
        print("  Cartes generees :")
        print("  map_initial.png    -> routes optimisees")
        print("  map_apres_ajout.png -> apres nouvelle commande")
        print("  map_pareto.png     -> front de Pareto")
        print("=" * 60)


if __name__ == "__main__":
    main()