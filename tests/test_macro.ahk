#Requires AutoHotkey v2.0
; =============================================================================
;  TESTS de Farm_Peche.ahk (double-clic pour lancer, ça prend environ une minute)
;  Rien n'est envoyé au jeu : pas une touche, pas un clic. On teste :
;   1. les calculs (place qui reste dans l'inventaire)
;   2. la lecture de l'écran sur une vraie capture (coffre_transfo.png, coffre ouvert)
;   3. récolte, transfo et vente de bout en bout, dans un faux jeu qui réagit comme FiveM
;      (coffre, poids, refus quand c'est trop lourd, transfo toutes les 6 s, vente)
;  Le résultat s'affiche à la fin et est écrit dans resultats.txt.
;  En ligne de commande : AutoHotkey64.exe test_macro.ahk --console (pas de fenêtre)
; =============================================================================

MODE_TEST := true
#Include %A_ScriptDir%\..\Farm_Peche.ahk

LOGS_ACTIFS := false
FICHIER_RESULTATS := A_ScriptDir "\resultats.txt"
CONSOLE := (A_Args.Length && A_Args[1] = "--console")
RESULTATS := "", NB_OK := 0, ECHECS := [], ERREURS_SCRIPT := []
try FileDelete FICHIER_RESULTATS
OnError(ErreurPendantTest, -1)

RESS := "Ressources précieuses"
PIER := "pierres précieuses"           ; écrit comme dans le jeu : la recherche ignore la casse
BRUT := RESS, PRODUIT := "Pierres précieuses", POIDS_MAX := 103

Ecrire("Tests " VERSION " - " FormatTime(, "yyyy-MM-dd HH:mm:ss"))

; =============================================================================
Section("1. Calculs")
; =============================================================================

Egal(ObjetsQuiRentrent(103, 66 / 103, 0.2, 2), 175, "66 kg sur 103 : (103 - 66 - 2) / 0,2 = 175")
Egal(ObjetsQuiRentrent(103, 46 / 103, 0.2, 2), 275, "46 kg sur 103 : 275")
Egal(ObjetsQuiRentrent(138, 66 / 138, 0.2, 2), 350, "autre perso, 66 kg sur 138 : 350")
Egal(ObjetsQuiRentrent(103, 0, 0.2, 2), 505, "inventaire vide : 505")
Egal(ObjetsQuiRentrent(103, 1, 0.2, 2), 0, "inventaire plein : 0")
Egal(ObjetsQuiRentrent(103, 102 / 103, 0.2, 2), 0, "moins de 2 kg libres : 0 (jamais négatif)")

; =============================================================================
Section("2. Lecture d'une vraie capture (coffre ouvert, 46 / 103 kg, véhicule 1000 / 1000)")
; =============================================================================

img := ChargerImage(A_ScriptDir "\coffre_transfo.png")
Verifier(IsObject(img), "capture chargée")
if IsObject(img) {
    ECRAN_TEST := img
    PROFIL := {fx: 1, fy: 1, ox: 0, oy: 0, exact: true}
    CalculerPositions()

    ; calibration : les deux barres rouges sont là où le profil les attend
    y1 := Round(img.h * 0.15), y2 := Round(img.h * 0.215)
    bande := Capture(img.w, y2 - y1 + 1)
    bande.Prendre(0, y1)
    g := TrouverBarre(bande, 0, Round(img.w * 0.20))
    d := TrouverBarre(bande, Round(img.w * 0.50), Round(img.w * 0.80))
    ; (à 1 pixel près : les coins arrondis de la barre commencent 1 pixel plus loin)
    Verifier(IsObject(g) && Abs(g.x - 65) <= 1 && Abs(y1 + g.y - 275) <= 1, "calibration : barre de l'inventaire en 65, 275")
    Verifier(IsObject(d) && Abs(d.x - 1657) <= 1 && Abs(y1 + d.y - 275) <= 1, "calibration : barre du véhicule en 1657, 275")

    Verifier(InventaireOuvert(), "inventaire ouvert vu")
    Verifier(CoffreOuvert(), "coffre ouvert vu (titre Véhicule)")
    Entre(POIDS_MAX * RemplissageInventaire(), 46, 47, "poids lu sur la barre : 46 kg (affiché 46 / 103 Kg)")
    Verifier(VehiculePlein(), "véhicule plein vu (1000 / 1000 Kg)")
    Entre(PlaceInventaire(), 270, 275, "vente : place pour (103 - 46 - 2) / 0,2 = 275 pierres, à 1 kg près")
    Verifier(Detecte("veh", 1) && Detecte("veh", 2) && !Detecte("veh", 3), "véhicule : 2 objets, 3e case vide")
    Verifier(Detecte("inv", 1) && Detecte("inv", 5), "inventaire : cases occupées vues")
    Egal(AuMoins100("veh"), 1, "véhicule : 2600 Ressources = au moins 100")
    Verifier(AuMoins100("inv") != 1, "inventaire : le téléphone n'a pas de nombre, pas de dépôt")
    ; nombre de chiffres lus en haut à gauche de cases connues : [côté, ligne, colonne, nombre]
    for t in [["inv", 1, 2, "173"], ["inv", 1, 3, "5"], ["inv", 1, 4, "300"], ["inv", 1, 5, "2"]
            , ["inv", 2, 4, "5"], ["inv", 3, 1, "6"], ["inv", 3, 3, "100"], ["inv", 3, 4, "6"]
            , ["inv", 4, 1, "5"], ["inv", 5, 5, "2310"], ["inv", 6, 1, "210"]
            , ["veh", 1, 1, "2600"], ["veh", 1, 2, "2400"]] {
        x0 := (t[1] = "inv") ? 65 : 1657
        n := CompterChiffres(EcX(x0 + PAS_CASE * (t[3] - 1)), EcY(344 + PAS_CASE * (t[2] - 1)))
        Egal(n, StrLen(t[4]), "chiffres lus : " t[4] " (" t[1] ", ligne " t[2] ", case " t[3] ")")
    }

    ; écran sans inventaire (en jeu) : rien n'est vu, donc aucun clic
    ECRAN_TEST := ImageNoire(img.w, img.h)
    Verifier(!InventaireOuvert() && !CoffreOuvert(), "écran de jeu : ni inventaire ni coffre vus")
    Egal(RemplissageCamion(), -1, "écran de jeu : pas de barre du véhicule")
    ; inventaire seul (Tab) : la même capture sans le titre "Véhicule"
    ECRAN_TEST := SansZone(img, 1640, 222, 1800, 256)
    Verifier(InventaireOuvert() && !CoffreOuvert(), "inventaire seul (Tab) : pas pris pour le coffre")
    ECRAN_TEST := 0
}

; =============================================================================
Section("3. Récolte (jeu simulé)")
; =============================================================================

j := Lancer(JeuSimule({veh: Map(RESS, 4600), recolte: 12}), "recolte")
Egal(Debut(j, 1), "l", "coffre fermé au départ : ouvert avec L")
Egal(Glisses(j, "inv"), "100,100,100,100", "4 dépôts de 100, rien d'autre")
Egal(j.Qte("veh", RESS), 5000, "véhicule rempli jusqu'au bout (5000 = 1000 kg)")
Egal(Fin(j, 2), "Tab,e", "véhicule plein : Tab puis E")
Verifier(InStr(RAISON_ARRET, "plein"), "arrêt : véhicule plein", RAISON_ARRET)
PasDErreur(j)

j := Lancer(JeuSimule({ecran: "inventaire", inv: Map(RESS, 100), veh: Map(RESS, 4900), recolte: 12}), "recolte")
Egal(Touches(j), "Tab,l,Tab,e", "inventaire seul ouvert au départ : Tab, L, dépôt, puis Tab, E")
PasDErreur(j)

j := Lancer(JeuSimule({veh: Map(RESS, 5000), recolte: 12}), "recolte")
Egal(Touches(j), "l,Tab", "lancée avec un véhicule déjà plein : L, Tab et pas de E")
Egal(Glisses(j, "inv"), "", "lancée avec un véhicule déjà plein : aucun dépôt")

j := Lancer(JeuSimule({veh: Map(RESS, 1000), verrouille: true, recolte: 12}), "recolte")
Verifier(InStr(RAISON_ARRET, "Coffre inaccessible"), "véhicule verrouillé : arrêt avec un message", RAISON_ARRET)
Egal(Compte(j.touches, "u"), 0, "véhicule verrouillé : le script ne touche pas au verrou")

; =============================================================================
Section("4. Transfo (jeu simulé, 12 objets transformés toutes les 6 s)")
; =============================================================================

j := Lancer(JeuSimule({ecran: "coffre", veh: Map(RESS, 600, PIER, 4400), transfo: 12}), "transfo")
Egal(PremierePrise(j), 200, "première prise : 200")
Verifier(PlusGrossePrise(j) <= 200, "jamais plus de 200 pris d'un coup", PlusGrossePrise(j))
Egal(j.Qte("veh", PIER), 5000, "tout est transformé et redéposé (5000 pierres)")
Egal(j.Qte("veh", RESS) + j.Qte("inv", RESS) + j.Qte("inv", PIER), 0, "plus rien dans l'inventaire ni à transformer")
Egal(Fin(j, 2), "Tab,u", "fin : Tab puis U")
Egal(Compte(j.touches, "u"), 1, "U appuyé une seule fois")
Verifier(j.poidsMaxVu <= 101, "inventaire jamais au-delà de 101 kg (2 kg de marge)", j.poidsMaxVu " kg")
Verifier(InStr(RAISON_ARRET, "verrouillé"), "arrêt : transfo terminée, véhicule verrouillé", RAISON_ARRET)
PasDErreur(j)

; la situation de la capture : véhicule plein (2600 + 2400) et 100 pierres déjà dans l'inventaire
j := Lancer(JeuSimule({ecran: "coffre", veh: Map(RESS, 2600, PIER, 2400), inv: Map(PIER, 100), transfo: 12}), "transfo")
Egal(j.Qte("veh", RESS) + j.Qte("inv", RESS), 0, "situation de la capture : tout est transformé")
Egal(j.Qte("veh", PIER), 5000, "situation de la capture : véhicule plein de pierres")
Egal(j.Qte("inv", PIER), 100, "situation de la capture : les 100 en trop restent dans l'inventaire")
Egal(Fin(j, 2), "Tab,u", "situation de la capture : fin par Tab puis U")
Verifier(j.refusesDePlus <= 3, "situation de la capture : pas de dépôts refusés en boucle", j.refusesDePlus " refusés")
PasDErreur(j)

j := Lancer(JeuSimule({ecran: "coffre", veh: Map(RESS, 300, PIER, 2000), transfo: 12}), "transfo")
Egal(j.Qte("veh", PIER), 2300, "véhicule pas plein : tout est quand même transformé et redéposé")
Egal(Compte(j.touches, "u") + Compte(j.touches, "Tab"), 0, "véhicule pas plein à la fin : ni Tab ni U")
Verifier(InStr(RAISON_ARRET, "pas plein"), "arrêt : véhicule pas plein, pas de verrouillage", RAISON_ARRET)
PasDErreur(j)

j := Lancer(JeuSimule({ecran: "coffre", veh: Map(RESS, 2000, PIER, 3000), transfo: 0}), "transfo")
Verifier(InStr(RAISON_ARRET, "Rien ne se transforme"), "hors de la zone : arrêt avec un message", RAISON_ARRET)
Egal(Compte(j.touches, "u"), 0, "hors de la zone : pas de U")
Verifier(j.poidsMaxVu <= 101, "hors de la zone : inventaire jamais au-delà de 101 kg", j.poidsMaxVu " kg")
PasDErreur(j)

; =============================================================================
Section("5. Vente (jeu simulé)")
; =============================================================================

j := Lancer(JeuSimule({veh: Map(PIER, 600), invAutres: 66, zoneVente: true}), "vente")
Egal(PremierePrise(j), 175, "66 kg sur 103 : prend 175 d'un coup")
Egal(Debut(j, 7), "l,Tab,e,Enter,Tab,Enter,l", "L, prise, Tab (sortie du coffre), E et la suite, L...")
Egal(Glisses(j, "veh"), "175,175,175,175!,128!,64,32!,16!,8,4!,2,1", "fin du stock (75) : tout est pris sans connaître le nombre")
Egal(j.vendus, 600, "tout le véhicule est vendu")
Verifier(j.poidsMaxVu <= 101, "inventaire jamais au-delà de 101 kg", j.poidsMaxVu " kg")
Verifier(InStr(RAISON_ARRET, "vente terminée"), "arrêt : plus rien dans le véhicule", RAISON_ARRET)
PasDErreur(j)

j := Lancer(JeuSimule({veh: Map(PIER, 600), invAutres: 46, inv: Map(PIER, 30), zoneVente: true}), "vente")
Egal(PremierePrise(j), 245, "46 kg + 30 pierres déjà sur toi (52 kg) : prend 245, puis vend tout")
Egal(j.vendus, 630, "les 30 déjà sur toi sont vendus aussi")

j := Lancer(JeuSimule({veh: Map(PIER, 600), invAutres: 102, zoneVente: true}), "vente")
Verifier(InStr(RAISON_ARRET, "Rien pu prendre"), "inventaire déjà plein : arrêt avec un message", RAISON_ARRET)
Egal(Compte(j.touches, "e"), 0, "inventaire déjà plein : pas de E")

; =============================================================================
Section("Bilan")
; =============================================================================

Egal(ERREURS_SCRIPT.Length, 0, "aucune erreur AutoHotkey pendant les tests", ERREURS_SCRIPT.Length ? ERREURS_SCRIPT[1] : "")
Ecrire("")
Ecrire(NB_OK " ok, " ECHECS.Length " échec(s)")
for e in ECHECS
    Ecrire("  - " e)
if !CONSOLE
    MsgBox(RESULTATS, "Tests " VERSION " : " (ECHECS.Length ? ECHECS.Length " échec(s)" : "tout est bon"), ECHECS.Length ? "Icon!" : "Iconi")
ExitApp ECHECS.Length ? 1 : 0

; =============================================================================
;  Faux jeu : réagit aux touches, recherches et glisser comme FiveM
; =============================================================================

class JeuSimule {
    __New(o) {
        this.t := 0, this.limite := 3600000       ; 1 h de jeu simulé au plus
        this.prochainLot := 6000                  ; un lot (récolte ou transfo) toutes les 6 s
        this.ecran := "jeu"                       ; jeu, inventaire (Tab), coffre, boutique
        this.verrouille := false
        this.inv := Map(), this.veh := Map()      ; objets de farm (0,2 kg chacun)
        this.invAutres := 26                      ; kg des autres objets de l'inventaire
        this.invMax := 103, this.vehMax := 1000
        this.rechInv := "", this.rechVeh := ""
        this.recolte := 0, this.transfo := 0      ; objets par lot (0 = pas de récolte / hors zone)
        this.zoneVente := false, this.entrees := 0, this.vendus := 0
        this.touches := [], this.glisses := [], this.erreurs := []
        this.refusesDePlus := 0
        for k, v in o.OwnProps()
            this.%k% := v
        this.poidsMaxVu := this.Poids("inv")
    }

    Stock(cote) => (cote = "inv") ? this.inv : this.veh
    Qte(cote, nom) => this.Stock(cote).Has(nom) ? this.Stock(cote)[nom] : 0
    Ajouter(cote, nom, n) => this.Stock(cote)[nom] := this.Qte(cote, nom) + n
    Poids(cote) {
        p := (cote = "inv") ? this.invAutres : 0
        for nom, q in this.Stock(cote)
            p += q * 0.2
        return Round(p, 3)
    }
    PoidsMax(cote) => (cote = "inv") ? this.invMax : this.vehMax

    InventaireOuvert() => (this.ecran = "inventaire" || this.ecran = "coffre")
    CoffreOuvert() => (this.ecran = "coffre")

    ; cases affichées d'un côté, filtrées par la recherche
    Cases(cote) {
        cases := []
        if (cote = "inv" ? !this.InventaireOuvert() : !this.CoffreOuvert())
            return cases
        rech := (cote = "inv") ? this.rechInv : this.rechVeh
        if (cote = "inv" && rech = "")
            cases.Push({nom: "Téléphone", q: 0})              ; objet sans nombre affiché
        for nom, q in this.Stock(cote)
            if (q > 0 && (rech = "" || InStr(nom, rech)))
                cases.Push({nom: nom, q: q})
        if (cote = "inv" && rech = "")
            cases.Push({nom: "Radio", q: 0})
        return cases
    }
    Detecte(cote, col) => this.Cases(cote).Length >= col
    SignatureQuantite(cote) {
        c := this.Cases(cote)
        return c.Length ? StrLen(c[1].nom) * 100000 + c[1].q : 0
    }
    AuMoins100(cote) {
        c := this.Cases(cote)
        if (!c.Length || c[1].q = 0)
            return -1
        return (c[1].q >= 100) ? 1 : 0
    }
    ; comme la vraie barre : au pixel près (838 pixels), arrondie vers le bas
    Remplissage(cote) {
        if (cote = "inv" ? !this.InventaireOuvert() : !this.CoffreOuvert())
            return (cote = "inv") ? 0 : -1
        p := this.Poids(cote)
        if (p <= 0)
            return (cote = "inv") ? 0 : -1
        return Min(1, Floor(p / this.PoidsMax(cote) * 838) / 838)
    }

    Rechercher(cote, nom) {
        if !this.InventaireOuvert()
            return false
        if (cote = "inv")
            this.rechInv := nom
        else if this.CoffreOuvert()
            this.rechVeh := nom
        return true
    }

    Glisser(x1, y1, x2, y2, q) {
        if !this.InventaireOuvert()
            return false
        de := (x1 = INV_X && y1 = INV_Y) ? "inv" : (x1 = VEH_X && y1 = VEH_Y) ? "veh" : ""
        vers := (x2 = INV2_X && y2 = INV2_Y) ? "inv" : ((x2 = VEH_X || x2 = VEH2_X) && y2 = VEH_Y) ? "veh" : ""
        if (!this.CoffreOuvert() || de = "" || vers = "" || de = vers) {
            this.erreurs.Push("glisser inattendu " x1 "," y1 " -> " x2 "," y2)
            return true
        }
        c := this.Cases(de)
        if (!c.Length || c[1].q = 0) {
            this.erreurs.Push("glisser d'une case sans objet de farm (" (c.Length ? c[1].nom : "vide") ")")
            return true
        }
        ; on lâche sur une case vide ou sur le même objet
        cible := this.Cases(vers), k := (x2 = VEH_X) ? 1 : 2
        if (cible.Length >= k && cible[k].nom != c[1].nom)
            this.erreurs.Push("lâché sur une case occupée par " cible[k].nom)
        ok := (q > 0 && q <= c[1].q && this.Poids(vers) + q * 0.2 <= this.PoidsMax(vers) + 0.001)
        this.glisses.Push({de: de, q: q, ok: ok})
        if ok {
            this.Ajouter(de, c[1].nom, -q)
            this.Ajouter(vers, c[1].nom, q)
            this.poidsMaxVu := Max(this.poidsMaxVu, this.Poids("inv"))
        } else if (de = "inv" && q = PAQUET) {
            this.refusesDePlus += 1
        }
        return true
    }

    Touche(t) {
        this.touches.Push(t)
        t := StrLower(t)
        if (this.ecran = "boutique") {                 ; e, Entrée, Tab, Entrée : vendu
            if (t = "enter" && ++this.entrees >= 2) {
                this.vendus += this.Qte("inv", PIER)
                this.inv[PIER] := 0
                this.ecran := "jeu"
            }
            return
        }
        if this.InventaireOuvert() {
            if (t = "tab")
                this.ecran := "jeu"
            else                                       ; la lettre s'écrirait dans une recherche
                this.erreurs.Push("touche " t " appuyée avec l'inventaire ouvert")
            return
        }
        switch t {
            case "l":
                if !this.verrouille
                    this.ecran := "coffre", this.rechInv := "", this.rechVeh := ""
            case "tab":
                this.ecran := "inventaire", this.rechInv := ""
            case "u":
                this.verrouille := !this.verrouille
            case "e":
                if this.zoneVente
                    this.ecran := "boutique", this.entrees := 0
                else
                    this.recolte := 0                  ; E arrête la récolte
        }
    }

    ; le temps passe (pauses du script) : récolte et transfo avancent
    Avancer(ms) {
        global enMarche
        this.t += ms
        while (this.t >= this.prochainLot) {
            this.prochainLot += 6000
            if (this.recolte > 0) {
                n := Min(this.recolte, Floor((this.invMax - this.Poids("inv")) / 0.2 + 0.001))
                if (n > 0)
                    this.Ajouter("inv", RESS, n), this.poidsMaxVu := Max(this.poidsMaxVu, this.Poids("inv"))
            }
            if (this.transfo > 0) {
                n := Min(this.transfo, this.Qte("inv", RESS))
                if (n > 0)
                    this.Ajouter("inv", RESS, -n), this.Ajouter("inv", PIER, n)
            }
        }
        if (this.t > this.limite && enMarche) {
            this.erreurs.Push("1 h de jeu simulé : le cycle ne s'arrête pas")
            enMarche := false
        }
    }
}

; Lance un cycle du script dans le faux jeu et attend qu'il s'arrête tout seul
Lancer(jeu, mode) {
    global SIMU, enMarche, enCours, activite, modeActuel, RAISON_ARRET
    SIMU := jeu, activite := "farm", modeActuel := mode
    RAISON_ARRET := "", enMarche := true, enCours := false
    debut := A_TickCount
    SetTimer Map("recolte", CycleRecolte, "transfo", CycleTransfo, "vente", CycleVente)[mode], -1
    Sleep 10                      ; le cycle tourne ici jusqu'au bout (il passe devant ce thread)
    while (enCours && A_TickCount - debut < 180000)
        Sleep 50
    SIMU := 0
    Ecrire("  (" mode " : " Round(jeu.t / 1000) " s de jeu simulé, " Round((A_TickCount - debut) / 1000, 1) " s réelles)")
    return jeu
}

; =============================================================================
;  Petits outils
; =============================================================================

Section(titre) => Ecrire("`n" titre)

Ecrire(t) {
    global RESULTATS
    RESULTATS .= t "`n"
    try FileAppend t "`n", FICHIER_RESULTATS, "UTF-8"
    if CONSOLE
        try FileAppend t "`n", "*", "UTF-8"
}

Verifier(cond, nom, detail := "") {
    global NB_OK
    if cond
        NB_OK += 1
    else
        ECHECS.Push(nom)
    Ecrire((cond ? "  ok     " : "  ECHEC  ") nom ((!cond && detail != "") ? "   [" detail "]" : ""))
}

Egal(obtenu, attendu, nom, detail := "") {
    Verifier(obtenu == attendu, nom, "obtenu " obtenu ", attendu " attendu (detail != "" ? " : " detail : ""))
}

Entre(v, a, b, nom) => Verifier(v >= a && v <= b, nom, "obtenu " Round(v, 2) ", attendu entre " a " et " b)

PasDErreur(j) => Verifier(!j.erreurs.Length, "aucune action dangereuse ou bizarre", j.erreurs.Length ? j.erreurs[1] : "")

Touches(j) => Joindre(j.touches)
Debut(j, n) => Joindre(j.touches, 1, n)
Fin(j, n) => Joindre(j.touches, j.touches.Length - n + 1, n)

Joindre(liste, depuis := 1, n := 0) {
    s := ""
    for i, v in liste
        if (i >= depuis && (n = 0 || i < depuis + n))
            s .= (s = "" ? "" : ",") v
    return s
}

Compte(liste, v) {
    n := 0
    for x in liste
        n += (x = v)
    return n
}

; quantités glissées depuis un côté, "!" quand le jeu a refusé
Glisses(j, de) {
    s := ""
    for g in j.glisses
        if (g.de = de)
            s .= (s = "" ? "" : ",") g.q (g.ok ? "" : "!")
    return s
}

PremierePrise(j) {
    for g in j.glisses
        if (g.de = "veh" && g.ok)
            return g.q
    return 0
}

PlusGrossePrise(j) {
    m := 0
    for g in j.glisses
        if (g.de = "veh" && g.ok)
            m := Max(m, g.q)
    return m
}

ErreurPendantTest(e, mode) {
    ERREURS_SCRIPT.Push(e.Message " (" e.What ", ligne " e.Line ")")
    Ecrire("  ERREUR AutoHotkey : " e.Message " (" e.What ", ligne " e.Line ")")
    return 0                       ; on laisse le script faire comme d'habitude
}

; Image PNG chargée en mémoire comme l'écran (pixels 0xRRGGBB), pour ECRAN_TEST
ChargerImage(chemin) {
    static jeton := 0
    if !FileExist(chemin)
        return 0
    if !jeton {
        DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
        si := Buffer(24, 0), NumPut("UInt", 1, si)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &jeton, "Ptr", si, "Ptr", 0)
    }
    bmp := 0
    if (DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", chemin, "Ptr*", &bmp) || !bmp)
        return 0
    w := 0, h := 0
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", bmp, "UInt*", &w)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", bmp, "UInt*", &h)
    rect := Buffer(16, 0), NumPut("Int", w, rect, 8), NumPut("Int", h, rect, 12)
    data := Buffer(32, 0)
    DllCall("gdiplus\GdipBitmapLockBits", "Ptr", bmp, "Ptr", rect, "UInt", 1, "Int", 0x26200A, "Ptr", data)
    stride := NumGet(data, 8, "Int"), scan0 := NumGet(data, 16, "Ptr")
    img := {w: w, h: h, buf: Buffer(w * h * 4)}
    img.ptr := img.buf.Ptr
    Loop h
        DllCall("RtlMoveMemory", "Ptr", img.ptr + (A_Index - 1) * w * 4, "Ptr", scan0 + (A_Index - 1) * stride, "UPtr", w * 4)
    DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", bmp, "Ptr", data)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
    return img
}

ImageNoire(w, h) {
    img := {w: w, h: h, buf: Buffer(w * h * 4, 0)}
    img.ptr := img.buf.Ptr
    return img
}

; Copie de l'image avec un rectangle passé en noir
SansZone(src, x1, y1, x2, y2) {
    img := {w: src.w, h: src.h, buf: Buffer(src.w * src.h * 4)}
    img.ptr := img.buf.Ptr
    DllCall("RtlMoveMemory", "Ptr", img.ptr, "Ptr", src.ptr, "UPtr", src.w * src.h * 4)
    y := y1
    while (y <= y2) {
        DllCall("RtlZeroMemory", "Ptr", img.ptr + (y * src.w + x1) * 4, "UPtr", (x2 - x1 + 1) * 4)
        y += 1
    }
    return img
}
