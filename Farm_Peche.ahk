#Requires AutoHotkey v2.0
#SingleInstance Force
; =============================================================================
;  MACRO FARM + PECHE
;  Pavé numérique :  7 = menu   8 = cacher / montrer le panneau   9 = lancer / arrêter
;  Pour fermer : clic droit sur l'icône H verte, "Exit".
;  Le jeu doit être en "fenêtré sans bordure".
;
;  Le coffre s'ouvre avec L : le véhicule doit être déverrouillé. Le script ne le verrouille
;  qu'à la fin de la transfo (U). Il ne clique jamais quand l'inventaire est fermé (en jeu,
;  un clic frapperait la personne devant toi). Si tu vas sur une autre fenêtre, il se met
;  en pause et reprend quand tu reviens sur FiveM.
;
;  RECOLTE : ouvre le coffre (L) si besoin, cherche l'objet récolté dans ton inventaire et,
;            dès qu'il y en a 100, les met dans le véhicule. En boucle jusqu'à ce que le
;            véhicule soit plein (1000/1000, 2000/2000...) : Tab, E, pause.
;  TRANSFO : objets transformés cherchés à gauche, objets à transformer à droite. Prend 200
;            (moins si ton poids ne le permet pas) ; dès que 100 sont transformés, il les
;            remet et en reprend 200. Fin quand le véhicule est plein ET n'a plus aucun
;            objet à transformer : Tab, U (verrouille le véhicule), pause.
;  VENTE   : prend d'un coup ce que ton inventaire peut porter en gardant 2 kg libres
;            (66 kg sur 103 : (103 - 66 - 2) / 0,2 = 175), ressort du coffre (Tab), puis E
;            et la suite de la vente. Le poids max de ton inventaire se règle dans le menu.
;  PECHE   : fait les QTE tout seul, et attache l'appât si tu coches la case.
;
;  Le script crée à côté de lui reglages.ini (tes choix, la latence de ton PC)
;  et un dossier logs (journal + images quand quelque chose rate).
; =============================================================================

; =============================================================================
;  PARTIE COMMUNE : capture d'écran, QTE, appât, inventaire, panneau, réglages, logs
; =============================================================================

CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
CoordMode "ToolTip", "Screen"
SendMode "Input"

FICHIER_INI  := A_ScriptDir "\reglages.ini"
DOSSIER_LOGS := A_ScriptDir "\logs"

; ---------- Pêche ----------
; Moment de l'appui dans la zone rouge (0 = tout début, 1 = toute fin)
CIBLE_MIN := 0.08
CIBLE_MAX := 0.12

; Latence (ms) entre l'appui et sa prise en compte par le jeu. Avec LATENCE_AUTO, le script
; la mesure lui-même à chaque QTE et la retient dans reglages.ini (une valeur par PC).
; CORRECTION_LATENCE s'ajoute à la mesure : mets 10 si ça tape encore trop tard, -10 si trop tôt.
LATENCE_AUTO       := true
LATENCE_DEPART     := 30
CORRECTION_LATENCE := 0

; Appât : nom exact dans l'inventaire pour chaque choix du menu
APPATS := Map("Eau douce", "Appât d'eau douce", "Mer", "Appât de mer", "Glaces", "Appât des glaces", "Tropical", "Appât tropical"
    , "Doigt sanglant", "Appât doigt sanglant")

; ---------- Rythme ----------
; Rythme des gestes dans l'inventaire (le QTE de pêche, lui, reste toujours au plus vite).
; 1 = rapide (quasi instantané), 2 = naturel, 3 = tranquille. Se change aussi dans le menu.
;   pause   : pause entre deux actions (ms)
;   souris  : durée des déplacements (0 = direct, 1 = normal, plus grand = plus lent)
;   frappe  : délai entre deux lettres tapées (ms), [0, 0] = tout d'un coup
;   souffle : 1 action sur N est suivie d'une petite pause en plus (0 = jamais)
RYTHMES := Map(
    1, {nom: "Rapide",     pause: [150, 220],  souris: 0,   frappe: [0, 0],    souffle: 0},
    2, {nom: "Naturel",    pause: [250, 450],  souris: 0.8, frappe: [45, 110], souffle: 18},
    3, {nom: "Tranquille", pause: [450, 800],  souris: 1.3, frappe: [80, 170], souffle: 10}
)

; Façon de placer la souris. Si le curseur saute ou si le glissé ne prend pas, essaie 2 puis 3.
METHODE_SOURIS := 1

; ---------- Logs ----------
LOGS_ACTIFS := true
LOGS_MAX    := 150      ; images enregistrées au maximum par session

; =============================================================================
;  Profil d'écran
;  Toutes les positions sont relevées sur un écran 2560x1440. EcX / EcY les convertissent
;  pour ton écran : proportionnellement par défaut, ou avec un profil exact si tu as fait
;  "Calibrer" dans le menu (coffre ouvert).
; =============================================================================

PROFIL := ChargerProfil()

ChargerProfil() {
    sec := "profil_" A_ScreenWidth "x" A_ScreenHeight
    fx := IniRead(FICHIER_INI, sec, "fx", "")
    if (fx != "") {
        return {fx: Float(fx), fy: Float(IniRead(FICHIER_INI, sec, "fy", fx))
            , ox: Float(IniRead(FICHIER_INI, sec, "ox", 0)), oy: Float(IniRead(FICHIER_INI, sec, "oy", 0)), exact: true}
    }
    return {fx: A_ScreenWidth / 2560, fy: A_ScreenHeight / 1440, ox: 0, oy: 0, exact: false}
}

EcX(v) => Round(PROFIL.ox + v * PROFIL.fx)
EcY(v) => Round(PROFIL.oy + v * PROFIL.fy)

CalculerPositions() {
    global
    ; inventaire (gauche) et véhicule (droite)
    RECH_INV_X := EcX(480),  RECH_INV_Y := EcY(310)
    RECH_VEH_X := EcX(2075), RECH_VEH_Y := EcY(310)
    INV_X := EcX(144),  INV_Y := EcY(420)          ; centre de la 1re case
    VEH_X := EcX(1737), VEH_Y := EcY(420)
    INV2_X := EcX(309), INV2_Y := EcY(420)         ; 2e case
    VEH2_X := EcX(1903), VEH2_Y := EcY(420)
    PAS_CASE := 165.6                               ; écart entre deux cases (en 2560)
    ; quantité en haut à gauche de la 1re case
    QUANT_INV_X := EcX(65),   QUANT_VEH_X := EcX(1657), QUANT_Y := EcY(344)
    Q_W := Round(85 * PROFIL.fx), Q_H := Round(22 * PROFIL.fy)
    Q_GAP := Max(3, Round(4 * PROFIL.fy))
    ; titre "Inventaire" et barre de poids de l'inventaire
    TITRE_X1 := EcX(60),  TITRE_Y1 := EcY(232)
    TITRE_X2 := EcX(200), TITRE_Y2 := EcY(246)
    BARRE_X := EcX(78),   BARRE_Y := EcY(275)
    IBARRE_X1 := EcX(40), IBARRE_X2 := EcX(920)
    IBARRE_DEB := PROFIL.ox + 65 * PROFIL.fx, IBARRE_LONG := 838 * PROFIL.fx   ; même longueur que celle du véhicule
    ; barre de poids du véhicule
    VBARRE_X1 := EcX(1640), VBARRE_X2 := EcX(2510), VBARRE_Y := EcY(275)
    VBARRE_DEB := PROFIL.ox + 1657 * PROFIL.fx, VBARRE_LONG := 838 * PROFIL.fx
    ; message "Attachez un appât à votre canne à pêche."
    MSG_G_X1 := EcX(895),  MSG_G_X2 := EcX(1000)
    MSG_D_X1 := EcX(1560), MSG_D_X2 := EcX(1664)
    MSG_Y1 := EcY(1385),   MSG_Y2 := EcY(1412)
    ; cercle du QTE
    CX := EcX(1280), CY := EcY(720)
    R_MID     := Round(64.8 * PROFIL.fy)
    R_ECART   := Max(1, Round(2.0 * PROFIL.fy))
    R_SCAN    := Round(17.3 * PROFIL.fy)
    R_DEPASSE := Max(2, Round(2.0 * PROFIL.fy))
    L_DEMI    := Round(12.4 * PROFIL.fy)
    CAP_DEMI  := R_MID + R_SCAN + 6
    ; les photos et tables précalculées dépendent de ces tailles
    cap := 0
    OFFSETS_CACHE := Map()
    CAPTURES := Map()
}

DEG := 0.0174532925199433
cap := 0
OFFSETS_CACHE := Map()
CAPTURES := Map()
CalculerPositions()

; Forme des lettres du QTE (grille 5x6), calculée à partir de vos captures
MODELES := Map(
    "Z", [0.64, 0.66, 0.74, 0.95, 0.82, 0.00, 0.01, 0.46, 0.85, 0.14, 0.00, 0.20, 0.91, 0.27, 0.00, 0.12, 0.81, 0.45, 0.00, 0.00, 0.65, 0.66, 0.09, 0.05, 0.04, 0.98, 0.98, 0.97, 0.97, 0.95],
    "Q", [0.32, 0.74, 0.71, 0.69, 0.11, 0.81, 0.13, 0.00, 0.44, 0.81, 0.82, 0.02, 0.00, 0.23, 0.96, 0.81, 0.10, 0.19, 0.43, 0.80, 0.41, 0.69, 0.75, 0.87, 0.20, 0.01, 0.23, 0.35, 0.77, 0.25],
    "S", [0.46, 0.80, 0.73, 0.70, 0.26, 0.91, 0.22, 0.00, 0.13, 0.18, 0.62, 0.94, 0.67, 0.31, 0.03, 0.02, 0.18, 0.42, 0.78, 0.76, 0.67, 0.23, 0.15, 0.66, 0.86, 0.42, 0.95, 0.97, 0.75, 0.15],
    "D", [0.95, 0.71, 0.80, 0.61, 0.10, 0.86, 0.05, 0.01, 0.59, 0.67, 0.86, 0.05, 0.00, 0.30, 0.98, 0.86, 0.05, 0.00, 0.37, 0.90, 0.89, 0.15, 0.25, 0.82, 0.43, 0.98, 0.98, 0.98, 0.35, 0.02]
)

; ---------- État ----------
enMarche := false
enCours  := false
ECRAN_TEST := 0          ; tests seulement : une image à la place de l'écran
SIMU       := 0          ; tests seulement : un jeu simulé à la place de FiveM
MODE_TEST  := IsSet(MODE_TEST) && MODE_TEST   ; true quand le script est inclus par les tests
LATENCE_JEU := Number(IniRead(FICHIER_INI, "reglages", "latence", LATENCE_DEPART))
MESURES_LATENCE := []
STATS := {appuis: 0, sansAppui: 0}      ; compteurs de la pêche
RYTHME := Integer(IniRead(FICHIER_INI, "reglages", "rythme", 2))
if !RYTHMES.Has(RYTHME)
    RYTHME := 2
RythmeActuel() => RYTHMES[RYTHME]
NB_LOGS := 0

DllCall("winmm\timeBeginPeriod", "UInt", 1)   ; pauses précises à la milliseconde
OnExit Quitter
OnError ErreurInattendue

; Une erreur dans le script ne doit pas le bloquer : on la note dans le journal, on lâche
; la souris et les touches, et 9 relance normalement.
ErreurInattendue(e, mode) {
    global enMarche, enCours
    try Journal("ERREUR : " e.Message " (" e.What ", ligne " e.Line ") " e.Extra)
    RelacherTouche()
    if GetKeyState("LButton")
        Click "Up"
    enMarche := false, enCours := false
    try Etat("erreur")
    try Info("Détails dans logs\journal.txt", 0)
    return 1                           ; pas de fenêtre d'erreur, le script continue
}

Quitter(*) {
    RelacherTouche()
    if GetKeyState("LButton")
        Click "Up"
    DllCall("winmm\timeEndPeriod", "UInt", 1)
}

; =============================================================================
;  Réglages (reglages.ini à côté du script)
; =============================================================================

LireReglage(cle, defaut) => IniRead(FICHIER_INI, "reglages", cle, defaut)

EcrireReglage(cle, valeur) {
    try IniWrite valeur, FICHIER_INI, "reglages", cle
}

; =============================================================================
;  Panneau d'état (en haut à droite, ne prend pas les clics)
;  Verre fumé : fond sombre translucide, coins arrondis (Windows ne floute pas le fond
;  d'une fenêtre qui n'a jamais le focus). Le rond et le mot en haut à droite donnent
;  l'état : vert en cours, orange en attente (tu n'es pas sur FiveM), gris en pause,
;  bleu arrêté (la raison est écrite en bas), rouge erreur.
; =============================================================================

ETATS := Map(
    "marche",  {mot: "En cours",   coul: "3DDC84"},
    "attente", {mot: "En attente", coul: "FFB547"},
    "pause",   {mot: "En pause",   coul: "8B93A1"},
    "arret",   {mot: "Arrêté",     coul: "6CB4FF"},
    "erreur",  {mot: "Erreur",     coul: "FF6B6B"}
)
PANNEAU := 0, PAN := 0
PAN_ETAT := "", PAN_MESSAGE := ""        ; rien d'affiché avant que les réglages soient lus
if !MODE_TEST
    CreerPanneau()

CreerPanneau() {
    global PANNEAU, PAN
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
    g.BackColor := "15171C"
    g.MarginX := 0, g.MarginY := 0
    PAN := {}
    g.SetFont("s14", "Segoe UI")
    PAN.rond := g.Add("Text", "x14 y6 w18", "●")
    g.SetFont("s11 w600 cFFFFFF", "Segoe UI")
    PAN.titre := g.Add("Text", "x34 y10 w160", "")
    g.SetFont("s8 bold", "Segoe UI")
    PAN.etat := g.Add("Text", "x196 y14 w108 Right", "")
    g.SetFont("s9 norm c8B93A1", "Segoe UI")
    PAN.detail := g.Add("Text", "x34 y32 w270", "")
    g.SetFont("s10 norm cE6EAF0", "Segoe UI")
    PAN.stats := g.Add("Text", "x16 w288", "")
    g.SetFont("s9 norm", "Segoe UI")
    PAN.msg := g.Add("Text", "x16 w288", "")
    g.Show("NoActivate x" (A_ScreenWidth - 330) " y30 w320 h60")
    try WinSetTransparent 225, g
    ; coins arrondis et liseré clair (Windows 11, sans effet ailleurs)
    for attr, val in Map(33, 2, 34, 0x4A433E) {
        b := Buffer(4), NumPut("UInt", val, b)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "UInt", attr, "Ptr", b, "UInt", 4)
    }
    PANNEAU := g
    SetTimer SurveillerJeu, 300
}

; etat : "marche", "pause", "arret" ou "erreur" ("attente" s'affiche tout seul)
Etat(etat) {
    global PAN_ETAT := etat
    MajPanneau()
}

Info(texte, duree := 2500) {
    global PAN_MESSAGE := texte
    ; un message permanent ne doit pas être effacé par la minuterie d'un message précédent
    SetTimer EffacerInfo, (duree > 0) ? -duree : 0
    MajPanneau()
}

EffacerInfo() {
    global PAN_MESSAGE := ""
    MajPanneau()
}

Compteurs(texte) {
    if PANNEAU
        Afficher(PAN.stats, texte), MajPanneau()
}

; Touche 8 : cache le panneau ou le réaffiche
BasculerPanneau(*) {
    static cache := false
    if !PANNEAU
        return
    cache := !cache
    if cache
        PANNEAU.Hide()
    else
        PANNEAU.Show("NoActivate")
}

EtatAffiche() => (PAN_ETAT = "marche" && !JeuActif()) ? "attente" : PAN_ETAT

; Passe en « En attente » dès que tu quittes FiveM pendant que le script tourne
SurveillerJeu() {
    static vu := ""
    if (EtatAffiche() != vu)
        vu := EtatAffiche(), MajPanneau()
}

MajPanneau() {
    static coulEtat := "", coulMsg := ""          ; couleurs déjà en place (rien à refaire)
    if (!PANNEAU || PAN_ETAT = "")
        return
    e := ETATS[EtatAffiche()], r := Resume()
    if (e.coul != coulEtat)
        coulEtat := e.coul, PAN.rond.SetFont("c" e.coul), PAN.etat.SetFont("c" e.coul)
    Afficher(PAN.etat, e.mot), Afficher(PAN.titre, r.titre), Afficher(PAN.detail, r.detail)
    ; en bas : le message, ou les touches utiles quand rien ne tourne
    msg := PAN_MESSAGE
    if (msg = "" && PAN_ETAT != "marche")
        msg := "9 pour lancer   ·   7 pour le menu"
    c := (PAN_MESSAGE = "") ? "c7D8594" : "cD0D6E0"
    if (c != coulMsg)
        coulMsg := c, PAN.msg.SetFont(c)
    Afficher(PAN.msg, msg)
    ; les lignes vides disparaissent, les messages longs passent sur plusieurs lignes
    PAN.detail.GetPos(, &y, , &h)
    y += h + 10
    for ctl in [PAN.stats, PAN.msg] {
        ctl.Visible := (ctl.Value != "")
        if !ctl.Visible
            continue
        h := HauteurTexte(ctl)
        ctl.Move(, y, , h)
        y += h + 4
    }
    PANNEAU.Move(, , , y + 8)
}

Afficher(ctl, texte) {
    if (ctl.Value != texte)
        ctl.Value := texte
}

; Hauteur (px) du texte d'un contrôle, retours à la ligne compris
HauteurTexte(ctl) {
    ctl.GetPos(, , &w)
    hdc := DllCall("GetDC", "Ptr", ctl.Hwnd, "Ptr")
    ancien := DllCall("SelectObject", "Ptr", hdc, "Ptr", SendMessage(0x31, 0, 0, ctl), "Ptr")   ; WM_GETFONT
    rect := Buffer(16, 0), NumPut("Int", w, rect, 8)
    DllCall("DrawText", "Ptr", hdc, "Str", ctl.Value, "Int", -1, "Ptr", rect, "UInt", 0x410)   ; CALCRECT | WORDBREAK
    DllCall("SelectObject", "Ptr", hdc, "Ptr", ancien)
    DllCall("ReleaseDC", "Ptr", ctl.Hwnd, "Ptr", hdc)
    return NumGet(rect, 12, "Int")
}

; =============================================================================
;  Logs : journal.txt + images .bmp de ce que le script a vu quand ça rate
; =============================================================================

Journal(texte) {
    if !LOGS_ACTIFS
        return
    try {
        DirCreate DOSSIER_LOGS
        FileAppend FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") "  " texte "`n", DOSSIER_LOGS "\journal.txt", "UTF-8"
    }
}

SauverImage(c, nom) {
    global NB_LOGS
    if (!LOGS_ACTIFS || NB_LOGS >= LOGS_MAX || !IsObject(c))
        return
    NB_LOGS += 1
    try {
        DirCreate DOSSIER_LOGS
        chemin := DOSSIER_LOGS "\" FormatTime(A_Now, "yyyyMMdd_HHmmss") "_" NB_LOGS "_" nom ".bmp"
        c.SauverBmp(chemin)
        Journal("image : " chemin)
    }
}

; =============================================================================
;  Photo rapide d'un morceau d'écran, lue directement en mémoire
; =============================================================================

class Capture {
    __New(w, h) {
        this.w := w, this.h := h
        this.hdcEcran := DllCall("GetDC", "Ptr", 0, "Ptr")
        this.hdc := DllCall("CreateCompatibleDC", "Ptr", this.hdcEcran, "Ptr")
        bi := Buffer(40, 0)
        NumPut("UInt", 40, bi, 0)
        NumPut("Int", w, bi, 4)
        NumPut("Int", -h, bi, 8)
        NumPut("UShort", 1, bi, 12)
        NumPut("UShort", 32, bi, 14)
        pBits := 0
        this.hbm := DllCall("CreateDIBSection", "Ptr", this.hdc, "Ptr", bi, "UInt", 0, "Ptr*", &pBits, "Ptr", 0, "UInt", 0, "Ptr")
        this.bits := pBits
        this.ancien := DllCall("SelectObject", "Ptr", this.hdc, "Ptr", this.hbm, "Ptr")
    }
    Prendre(x, y) {
        if IsObject(ECRAN_TEST) {
            this.CopierImage(ECRAN_TEST, x, y)
            return
        }
        DllCall("BitBlt", "Ptr", this.hdc, "Int", 0, "Int", 0, "Int", this.w, "Int", this.h
            , "Ptr", this.hdcEcran, "Int", x, "Int", y, "UInt", 0x00CC0020)
    }
    ; pour les tests : copie un morceau d'une image chargée à la place de l'écran
    CopierImage(img, x, y) {
        DllCall("RtlZeroMemory", "Ptr", this.bits, "UPtr", this.w * this.h * 4)
        x0 := Max(0, x), x1 := Min(img.w, x + this.w)
        if (x1 <= x0)
            return
        Loop this.h {
            sy := y + A_Index - 1
            if (sy < 0 || sy >= img.h)
                continue
            DllCall("RtlMoveMemory", "Ptr", this.bits + ((A_Index - 1) * this.w + (x0 - x)) * 4
                , "Ptr", img.ptr + (sy * img.w + x0) * 4, "UPtr", (x1 - x0) * 4)
        }
    }
    Pixel(x, y) {
        if (x < 0 || y < 0 || x >= this.w || y >= this.h)
            return 0
        return NumGet(this.bits, (y * this.w + x) * 4, "UInt") & 0xFFFFFF
    }
    SauverBmp(chemin) {
        taille := this.w * this.h * 4
        entete := Buffer(54, 0)
        NumPut("UShort", 0x4D42, entete, 0)
        NumPut("UInt", 54 + taille, entete, 2)
        NumPut("UInt", 54, entete, 10)
        NumPut("UInt", 40, entete, 14)
        NumPut("Int", this.w, entete, 18)
        NumPut("Int", -this.h, entete, 22)
        NumPut("UShort", 1, entete, 26)
        NumPut("UShort", 32, entete, 28)
        NumPut("UInt", taille, entete, 34)
        f := FileOpen(chemin, "w")
        f.RawWrite(entete, 54)
        f.RawWrite(this.bits, taille)
        f.Close()
    }
    __Delete() {
        DllCall("SelectObject", "Ptr", this.hdc, "Ptr", this.ancien)
        DllCall("DeleteObject", "Ptr", this.hbm)
        DllCall("DeleteDC", "Ptr", this.hdc)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", this.hdcEcran)
    }
}

; Photo réutilisable d'une zone (recréée si la taille change après une calibration)
CapZone(nom, w, h) {
    if CAPTURES.Has(nom) {
        c := CAPTURES[nom]
        if (c.w = w && c.h = h)
            return c
    }
    c := Capture(w, h)
    CAPTURES[nom] := c
    return c
}

; Photographie le rectangle (x1, y1) - (x2, y2) et renvoie la photo
Photo(nom, x1, y1, x2, y2) {
    c := CapZone(nom, x2 - x1 + 1, y2 - y1 + 1)
    c.Prendre(x1, y1)
    return c
}

; Couleur d'un seul pixel de l'écran
Pixel1(x, y) {
    c := Photo("pixel", x, y, x, y)
    return c.Pixel(0, 0)
}

; Compte les pixels "texte clair" (blanc ou gris clair, même jauni par un filtre)
CompterClairs(c, seuil := 190, ecart := 70) {
    n := 0
    Loop c.h {
        y := A_Index - 1
        Loop c.w {
            p := c.Pixel(A_Index - 1, y)
            r := (p >> 16) & 0xFF, g := (p >> 8) & 0xFF, b := p & 0xFF
            ma := Max(r, g, b)
            if (ma >= seuil && ma - Min(r, g, b) < ecart)
                n += 1
        }
    }
    return n
}

EstRouge(p) {
    r := (p >> 16) & 0xFF, g := (p >> 8) & 0xFF, b := p & 0xFF
    return r >= 150 && r - g >= 45 && r - b >= 45
}

; Horloge précise en millisecondes
Maintenant() {
    static f := 0
    if !f
        DllCall("QueryPerformanceFrequency", "Int64*", &f)
    c := 0
    DllCall("QueryPerformanceCounter", "Int64*", &c)
    return c * 1000 / f
}

; Le script n'agit que si FiveM est la fenêtre au premier plan
JeuActif() {
    if (IsObject(ECRAN_TEST) || SIMU)
        return true
    try return InStr(WinGetProcessName("A"), "FiveM") > 0
    return false
}

; =============================================================================
;  Inventaire
; =============================================================================

; Titre blanc "Inventaire" + barre rouge de poids visibles en haut à gauche
InventaireOuvert() {
    if SIMU
        return SIMU.InventaireOuvert()
    if (CompterClairs(Photo("titre", TITRE_X1, TITRE_Y1, TITRE_X2, TITRE_Y2)) < 20)
        return false
    p := Pixel1(BARRE_X, BARRE_Y)
    r := (p >> 16) & 0xFF, g := (p >> 8) & 0xFF
    return r >= 150 && r - g >= 60
}

; "Véhicule" écrit en blanc en haut à droite : c'est le coffre qui est ouvert,
; pas seulement l'inventaire (Tab)
CoffreOuvert() {
    if SIMU
        return SIMU.CoffreOuvert()
    if !InventaireOuvert()
        return false
    return CompterClairs(Photo("vtitre", EcX(1655), EcY(232), EcX(1770), EcY(246))) >= 20
}

; Zone du nom écrit sous une case (cote = "inv" ou "veh", colonne 1 = 1re case)
ZoneNom(cote, colonne := 1) {
    x0 := (cote = "inv") ? 75 : 1665
    x := x0 + PAS_CASE * (colonne - 1)
    return [EcX(x), EcY(474), EcX(x + 140), EcY(496)]
}

; Y a-t-il un objet (un nom écrit) dans cette case ?
Detecte(cote, colonne := 1) {
    if SIMU
        return SIMU.Detecte(cote, colonne)
    z := ZoneNom(cote, colonne)
    return CompterClairs(Photo("nom", z[1], z[2], z[3], z[4]), 170, 70) >= 15
}

; Tape le nom dans la barre de recherche : l'objet passe en 1re case
; Jamais de clic si l'inventaire n'est pas ouvert : en jeu, un clic frapperait la personne
; devant toi. Renvoie false si l'action n'a pas pu se faire.
Rechercher(cote, nom) {
    if SIMU
        return SIMU.Rechercher(cote, nom)
    if !InventaireOuvert()
        return false
    if (cote = "inv")
        BougerVers(RECH_INV_X, RECH_INV_Y)
    else
        BougerVers(RECH_VEH_X, RECH_VEH_Y)
    if !InventaireOuvert()
        return false
    Click
    Geste(80)
    AttendreLeJeu()
    Send "^a"
    Geste(30)
    Taper(nom)
    Attendre(300, 400)         ; le temps que la liste se filtre
    return true
}

; Vérifie que la recherche est bien en place avant de glisser : la 1re case contient un
; objet et, si le nom ne correspond qu'à un seul objet (unique), la 2e case est vide.
; Si ce n'est pas le cas, on refait la recherche, mais au plus une fois toutes les 15 s
; (pour ne jamais taper en boucle dans la barre de recherche).
VerifierCase(cote, nom, unique := true) {
    static derniere := Map()
    if CaseOk(cote, unique)
        return true
    cle := cote "|" nom
    if (derniere.Has(cle) && A_TickCount - derniere[cle] < 15000)
        return false
    derniere[cle] := A_TickCount
    Rechercher(cote, nom)
    Sleep 300
    if CaseOk(cote, unique)
        return true
    xc := (cote = "inv") ? 60 : 1650
    SauverImage(Photo("logcase", EcX(xc), EcY(335), EcX(xc + 340), EcY(500)), "case_" cote)
    Journal("Case " cote " : " nom " pas trouvé après la recherche")
    return false
}

CaseOk(cote, unique) => Detecte(cote, 1) && (!unique || !Detecte(cote, 2))

; Glisse la 1re case d'un côté vers l'autre et tape la quantité
Glisser(x1, y1, x2, y2, quantite) {
    if SIMU
        return SIMU.Glisser(x1, y1, x2, y2, quantite)
    if !InventaireOuvert()
        return false
    BougerVers(x1, y1)
    Geste(40)
    if !InventaireOuvert()
        return false
    Click "Down"
    Geste(60)
    BougerVers(x2, y2)
    Geste(60)
    Click "Up"
    ; À partir d'ici la fenêtre de quantité est ouverte : le geste va jusqu'au bout, même si
    ; tu appuies sur 9 ou 7 (sinon elle resterait ouverte en jeu). Pas de vérification de
    ; l'écran non plus : la fenêtre assombrit l'inventaire, le script le croirait fermé.
    PauseGeste()
    AttendreLeJeu()            ; jamais de quantité tapée dans une autre fenêtre
    Taper(String(quantite))
    Geste(50)
    AttendreLeJeu()
    Send "{Enter}"
    Attendre()
    return true
}

; Appuie sur une touche du jeu. Si tu es sur une autre fenêtre, on attend ton retour ;
; si le script a été arrêté entre-temps, on n'appuie pas.
Touche(t) {
    if SIMU
        return SIMU.Touche(t)
    while (enMarche && !JeuActif())
        Sleep 100
    if !JeuActif()
        return
    Send "{" t " down}"
    Sleep Random(50, 90)
    Send "{" t " up}"
}

; Pause du rythme choisi, qu'on n'interrompt pas (milieu d'un geste)
PauseGeste() {
    Sleep Random(RythmeActuel().pause[1], RythmeActuel().pause[2])
}

; Milieu d'un geste : on attend que FiveM soit au premier plan avant de taper quoi que ce soit
AttendreLeJeu() {
    while !JeuActif()
        Sleep 100
}

; =============================================================================
;  Souris, clavier, pauses
; =============================================================================

; Pause découpée en petits morceaux, pour s'arrêter tout de suite quand on appuie sur 9.
; Si tu passes sur une autre fenêtre, on attend que tu reviennes sur le jeu.
Attendre(mini := 0, maxi := 0) {
    global enCours
    if (mini = 0) {
        mini := RythmeActuel().pause[1]
        maxi := RythmeActuel().pause[2]
        ; de temps en temps, une petite pause en plus, comme quelqu'un qui souffle
        if (RythmeActuel().souffle > 0 && Random(1, RythmeActuel().souffle) = 1)
            maxi += Random(600, 1800)
    }
    if SIMU {
        SIMU.Avancer(Random(mini, maxi))
    } else {
        fin := A_TickCount + Random(mini, maxi)
        while (enMarche && A_TickCount < fin)
            Sleep Max(1, Min(50, fin - A_TickCount))
    }
    if (enMarche && !JeuActif()) {
        if GetKeyState("LButton")
            Click "Up"
        while (enMarche && !JeuActif())
            Sleep 200
    }
    if !enMarche {
        if GetKeyState("LButton")
            Click "Up"
        enCours := false
        Exit
    }
}

; Déplacement de la souris. En rythme rapide : direct en 4 petits pas (le glisser-déposer
; a besoin de quelques mouvements intermédiaires). Sinon : trajet légèrement courbé qui
; accélère puis ralentit, avec une durée qui dépend de la distance.
BougerVers(x, y) {
    MouseGetPos &x0, &y0
    dx := x - x0, dy := y - y0
    dist := Sqrt(dx * dx + dy * dy)
    if (RythmeActuel().souris = 0 || dist < 3) {
        Loop 4 {
            t := A_Index / 4
            PlacerSouris(Round(x0 + dx * t), Round(y0 + dy * t))
            Sleep 6
        }
        return
    }
    courbe := Random(-0.15, 0.15) * dist
    cx := x0 + dx / 2 - dy / dist * courbe
    cy := y0 + dy / 2 + dx / dist * courbe
    duree := Min(700, 140 + dist * Random(0.25, 0.4)) * RythmeActuel().souris
    etapes := Max(6, Round(duree / 12))
    Loop etapes {
        t := A_Index / etapes
        t := t < 0.5 ? 2 * t * t : 1 - ((-2 * t + 2) ** 2) / 2
        px := (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t ** 2 * x
        py := (1 - t) ** 2 * y0 + 2 * (1 - t) * t * cy + t ** 2 * y
        PlacerSouris(Round(px), Round(py))
        Sleep 10
    }
    PlacerSouris(x, y)
}

PlacerSouris(x, y) {
    if (METHODE_SOURIS = 1) {
        DllCall("SetCursorPos", "Int", x, "Int", y)
    } else if (METHODE_SOURIS = 2) {
        MouseGetPos &ax, &ay
        if (x != ax || y != ay)
            MouseMove x - ax, y - ay, 0, "R"
    } else {
        MouseMove x, y, 0
    }
}

Taper(chaine) {
    if (RythmeActuel().frappe[2] = 0) {
        AttendreLeJeu()
        SendText chaine
        return
    }
    Loop Parse chaine {
        AttendreLeJeu()            ; lettre par lettre : jamais dans une autre fenêtre
        SendText A_LoopField
        Sleep Random(RythmeActuel().frappe[1], RythmeActuel().frappe[2])
    }
}

; Petite pause « humaine » entre deux gestes rapprochés (rien en rythme rapide)
Geste(rapide) {
    Sleep (RythmeActuel().souris = 0) ? rapide : Round(rapide * Random(1.5, 2.5) * RythmeActuel().souris)
}

; =============================================================================
;  Démarrage / arrêt (touche 9)
; =============================================================================

Basculer(*) {
    global enMarche
    if (!enMarche && enCours) {
        Info("Je finis l'action en cours…", 1500)
        return
    }
    enMarche := !enMarche
    if enMarche {
        Etat("marche")
        LancerCycle()
    } else {
        Etat("pause")
    }
}

; =============================================================================
;  Pêche
; =============================================================================

CyclePeche() {
    global enCours
    enCours := true
    lettre := "", lettreVue := ""
    debutCercle := 0
    prochaineVerif := A_TickCount + 500
    MajCompteursPeche()
    while enMarche {
        if !JeuActif() {               ; le panneau affiche « En attente »
            lettre := "", lettreVue := ""
            Sleep 200
            continue
        }

        r := AnalyserQTE()
        if !r {
            lettre := "", lettreVue := "", debutCercle := 0
            if (appatAuto && A_TickCount >= prochaineVerif) {
                prochaineVerif := A_TickCount + 1000
                if MessageAppat() {
                    AttacherAppat()
                    prochaineVerif := A_TickCount + 4000
                }
            }
            Sleep 8
            continue
        }
        if !debutCercle
            debutCercle := A_TickCount
        if (lettre = "") {
            ; la lettre doit être lue deux fois de suite pareil avant qu'on y croie
            l1 := LireLettre()
            if (l1 = "" || l1 != lettreVue) {
                lettreVue := l1
                if (A_TickCount - debutCercle > 1500) {
                    ; cercle vu depuis 1,5 s mais lettre illisible : on garde une trace
                    SauverImage(cap, "lettre_illisible")
                    Journal("Lettre illisible")
                    debutCercle := A_TickCount + 600000
                }
                Sleep 3
                continue
            }
            lettre := l1
        }
        res := SuivreEtAppuyer(r, lettre)
        if (res > 0) {
            STATS.appuis += 1
            Info("Pêche : " lettre, 800)
            reaction := MesurerReaction(r, res)
            if (reaction > 0)
                AjouterMesureLatence(reaction)
            AttendreFinQTE(r, lettre)
        } else if (res = 0) {
            STATS.sansAppui += 1
            SauverImage(cap, "qte_sans_appui")
            Journal("QTE sans appui (trait jamais vu dans la zone)")
        }
        MajCompteursPeche()
        lettre := "", lettreVue := ""
    }
    enCours := false
}

MajCompteursPeche() {
    Compteurs("QTE " STATS.appuis "   ·   ratés " STATS.sansAppui "   ·   latence " Round(LATENCE_JEU) " ms")
}

; Suit le trait et appuie au bon moment. Sa vitesse est mesurée en moyenne depuis le début
; du QTE (le jeu affiche souvent la même image plusieurs fois de suite). On vise là où il
; sera quand la touche arrivera dans le jeu. Renvoie l'heure de l'appui, 0 si on n'a pas
; appuyé, -1 si le cercle a disparu.
SuivreEtAppuyer(r, lettre) {
    global DUREE_IMAGE
    l := Mod(r.fin - r.debut + 720, 360)
    if (l <= 0)
        return -1
    cible := Random(CIBLE_MIN, CIBLE_MAX) * l
    lastA := -1, tDebut := 0, cumul := 0, changements := 0, rates := 0
    t0 := A_TickCount
    while (enMarche && A_TickCount - t0 < 8000) {
        tCap := Maintenant()
        cap.Prendre(CX - CAP_DEMI, CY - CAP_DEMI)
        a := TrouverTrait(r.rIn, r.rOut)
        tFin := Maintenant()
        if (a < 0) {
            rates += 1
            if (rates > 40) {
                if !AnalyserQTE()
                    return -1
                rates := 0
            }
            Sleep 1
            continue
        }
        rates := 0
        if (lastA < 0) {
            tDebut := tCap, lastA := a
        } else {
            delta := Mod(a - lastA + 360, 360)
            if (delta < 120 && delta > 0) {
                cumul += delta
                changements += 1
            }
            lastA := a
        }
        ecoule := tCap - tDebut
        vitesse := (ecoule > 0) ? cumul / ecoule : 0
        vitesseSure := (ecoule >= 60 && cumul > 0)
        if (changements > 0)
            DUREE_IMAGE := ecoule / changements
        d := Mod(a - r.debut + 720, 360)
        if (d > (l + 360) / 2)
            d -= 360                ; le trait n'est pas encore arrivé dans la zone
        dPrevu := d + vitesse * ((tFin - tCap) + LATENCE_JEU)
        if (vitesseSure && dPrevu >= cible && dPrevu <= l && d <= l)
            return EnfoncerTouche(lettre)
        ; dans la zone mais il en sortira avant que la touche arrive : on tente quand même
        if (d >= 0 && d <= l && dPrevu > l)
            return EnfoncerTouche(lettre)
        Sleep 1
    }
    return 0
}

DUREE_IMAGE := 16
DERNIER_RATIO := 0

; Le jeu prend la touche dès qu'elle est enfoncée : c'est cette heure-là qui compte.
; Elle est relâchée un peu plus tard, pendant la mesure de la réaction.
TOUCHE_ENFONCEE := "", DUREE_APPUI := 50

EnfoncerTouche(lettre) {
    global TOUCHE_ENFONCEE, DUREE_APPUI
    t := Maintenant()
    TOUCHE_ENFONCEE := StrLower(lettre)
    DUREE_APPUI := Random(35, 70)
    Send "{" TOUCHE_ENFONCEE " down}"
    return t
}

RelacherTouche() {
    global TOUCHE_ENFONCEE
    if (TOUCHE_ENFONCEE != "") {
        Send "{" TOUCHE_ENFONCEE " up}"
        TOUCHE_ENFONCEE := ""
    }
}

; Temps entre l'appui et la réaction du cercle (il disparaît ou la zone change)
MesurerReaction(r, tAppui) {
    l := Mod(r.fin - r.debut + 720, 360)
    t := OffsetsRayon(R_MID)
    angles := [Mod(Round(r.debut + l * 0.3), 360), Mod(Round(r.debut + l * 0.5), 360), Mod(Round(r.debut + l * 0.7), 360)]
    reaction := -1
    while (Maintenant() - tAppui < 800) {
        if (TOUCHE_ENFONCEE != "" && Maintenant() - tAppui >= DUREE_APPUI)
            RelacherTouche()
        tCap := Maintenant()
        cap.Prendre(CX - CAP_DEMI, CY - CAP_DEMI)
        rouges := 0
        for a in angles
            rouges += RougeOff(t[a + 1])
        if (rouges <= 1) {
            reaction := tCap - tAppui
            break
        }
        Sleep 1
    }
    while (TOUCHE_ENFONCEE != "" && Maintenant() - tAppui < DUREE_APPUI)
        Sleep 1
    RelacherTouche()
    return reaction
}

; La réaction devient visible à l'image suivante, soit en moyenne une demi-image après la
; prise en compte de la touche : on la retire, puis on garde la médiane des 9 dernières mesures.
AjouterMesureLatence(reaction) {
    global LATENCE_JEU
    if !LATENCE_AUTO
        return
    mesure := Max(0, Min(150, reaction - DUREE_IMAGE / 2))
    MESURES_LATENCE.Push(mesure)
    if (MESURES_LATENCE.Length > 9)
        MESURES_LATENCE.RemoveAt(1)
    if (MESURES_LATENCE.Length >= 3) {
        copie := MESURES_LATENCE.Clone()
        LATENCE_JEU := Mediane(copie) + CORRECTION_LATENCE
        EcrireReglage("latence", Round(LATENCE_JEU))
    }
}

; Après un appui : on attend que le cercle disparaisse ou qu'un nouveau QTE arrive
AttendreFinQTE(ancien, lettre) {
    absent := 0
    t0 := A_TickCount
    while (enMarche && A_TickCount - t0 < 2500) {
        r := AnalyserQTE()
        if !r {
            absent += 1
            if (absent >= 2)
                return
        } else {
            absent := 0
            ecartZone := Abs(Mod(r.debut - ancien.debut + 540, 360) - 180)
            if (ecartZone > 15)
                return
            l := LireLettre()
            if (l != "" && l != lettre)
                return
        }
        Sleep 10
    }
}

; Photographie le cercle et renvoie {debut, fin, aiguille, rIn, rOut} en degrés
; (0 = en haut, sens des aiguilles d'une montre), ou 0 s'il n'y a pas de QTE.
AnalyserQTE() {
    global cap
    if !IsObject(cap)
        cap := Capture(CAP_DEMI * 2 + 1, CAP_DEMI * 2 + 1)
    cap.Prendre(CX - CAP_DEMI, CY - CAP_DEMI)

    ; 1. la zone rouge sur l'anneau, tous les 2 degrés
    t0 := OffsetsRayon(R_MID), tm := OffsetsRayon(R_MID - R_ECART), tp := OffsetsRayon(R_MID + R_ECART)
    ok := []
    nbOk := 0
    Loop 180 {
        i := (A_Index - 1) * 2 + 1
        v := (RougeOff(t0[i]) || RougeOff(tm[i]) || RougeOff(tp[i])) ? 1 : 0
        ok.Push(v)
        nbOk += v
    }
    if (nbOk = 0 || nbOk = 180)
        return 0
    k0 := 0
    Loop 180 {
        if !ok[A_Index] {
            k0 := A_Index - 1
            break
        }
    }
    meilleur := 0, debutM := 0, suite := 0, debutS := 0
    Loop 180 {
        j := Mod(k0 + A_Index, 180)
        if ok[j + 1] {
            if (suite = 0)
                debutS := j
            suite += 1
            if (suite > meilleur) {
                meilleur := suite
                debutM := debutS
            }
        } else {
            suite := 0
        }
    }
    if (meilleur < 4 || meilleur > 150)
        return 0
    debut := debutM * 2
    fin   := debut + (meilleur - 1) * 2

    ; 1b. hors de la zone, l'anneau doit être gris foncé (sinon ce n'est pas le QTE)
    gris := 0, totalG := 0
    Loop 90 {
        a := (A_Index - 1) * 4
        dz := Mod(a - debut + 720, 360)
        if (dz <= fin - debut + 4 || dz >= 356)
            continue
        totalG += 1
        c := NumGet(cap.bits, t0[a + 1], "UInt") & 0xFFFFFF
        cr := (c >> 16) & 0xFF, cg := (c >> 8) & 0xFF, cb := c & 0xFF
        mi := Min(cr, cg, cb), ma := Max(cr, cg, cb)
        if (ma - mi < 40 && mi >= 10 && ma <= 150)
            gris += 1
    }
    if (totalG < 10 || gris < totalG * 0.8)
        return 0

    ; 2. bords intérieur et extérieur de l'anneau, mesurés dans la zone
    ints := [], exts := []
    Loop 5 {
        a := debut + (meilleur - 1) * 2 * A_Index / 6
        rmin := 0, rmax := 0
        r := R_MID - R_SCAN
        while (r <= R_MID + R_SCAN) {
            if PixRouge(a, r) {
                if (rmin = 0)
                    rmin := r
                rmax := r
            }
            r += 1
        }
        if rmin {
            ints.Push(rmin)
            exts.Push(rmax)
        }
    }
    if (ints.Length = 0)
        return 0
    rIn  := Mediane(ints)
    rOut := Mediane(exts)

    ; 3. le trait
    aiguille := TrouverTrait(rIn, rOut)
    return {debut: debut, fin: fin, aiguille: aiguille, rIn: rIn, rOut: rOut}
}

; Positions (en octets dans la photo du cercle) des 360 points d'un cercle de rayon r
OffsetsRayon(r) {
    if OFFSETS_CACHE.Has(r)
        return OFFSETS_CACHE[r]
    cote := CAP_DEMI * 2 + 1
    t := []
    Loop 360 {
        a := (A_Index - 1) * DEG
        x := Round(CAP_DEMI + r * Sin(a))
        y := Round(CAP_DEMI - r * Cos(a))
        t.Push((y * cote + x) * 4)
    }
    OFFSETS_CACHE[r] := t
    return t
}

RougeOff(off) {
    return EstRouge(NumGet(cap.bits, off, "UInt"))
}

PixRouge(a, r) {
    x := Round(CAP_DEMI + r * Sin(a * DEG))
    y := Round(CAP_DEMI - r * Cos(a * DEG))
    return EstRouge(cap.Pixel(x, y))
}

; Le trait dépasse de l'anneau des deux côtés (pas la zone) : renvoie son angle, ou -1
TrouverTrait(rIn, rOut) {
    tExt := OffsetsRayon(rOut + R_DEPASSE)
    tInt := OffsetsRayon(rIn - R_DEPASSE)
    cand := []
    nbC := 0
    Loop 360 {
        v := (RougeOff(tExt[A_Index]) && RougeOff(tInt[A_Index])) ? 1 : 0
        cand.Push(v)
        nbC += v
    }
    if (nbC = 0 || nbC = 360)
        return -1
    k0 := 0
    Loop 360 {
        if !cand[A_Index] {
            k0 := A_Index - 1
            break
        }
    }
    aiguille := -1, suite := 0, debutS := 0, meilleurA := 0
    Loop 360 {
        j := Mod(k0 + A_Index, 360)
        if cand[j + 1] {
            if (suite = 0)
                debutS := j
            suite += 1
        } else if (suite > 0) {
            if (suite <= 12 && suite > meilleurA) {
                meilleurA := suite
                aiguille := Mod(debutS + (suite - 1) / 2, 360)
            }
            suite := 0
        }
    }
    return aiguille
}

; Lit la lettre au centre du cercle (dans la dernière photo du cercle)
LireLettre() {
    n := L_DEMI * 2 + 1
    base := CAP_DEMI - L_DEMI
    encre := Buffer(n * n, 0)
    x0 := n, y0 := n, x1 := -1, y1 := -1, total := 0
    Loop n {
        yy := A_Index - 1
        Loop n {
            xx := A_Index - 1
            p := cap.Pixel(base + xx, base + yy)
            lum := (((p >> 16) & 0xFF) + ((p >> 8) & 0xFF) + (p & 0xFF)) / 3
            if (lum >= 120) {
                NumPut("UChar", 1, encre, yy * n + xx)
                x0 := Min(x0, xx), x1 := Max(x1, xx)
                y0 := Min(y0, yy), y1 := Max(y1, yy)
                total += 1
            }
        }
    }
    if (total < 8)
        return ""
    bw := x1 - x0 + 1, bh := y1 - y0 + 1
    cnt := [], tot := []
    Loop 30 {
        cnt.Push(0)
        tot.Push(0)
    }
    y := y0
    while (y <= y1) {
        x := x0
        while (x <= x1) {
            c := ((y - y0) * 6 // bh) * 5 + (x - x0) * 5 // bw + 1
            tot[c] += 1
            cnt[c] += NumGet(encre, y * n + x, "UChar")
            x += 1
        }
        y += 1
    }
    meilleure := "", d1 := 99999, d2 := 99999
    for lettre, modele in MODELES {
        d := 0
        Loop 30 {
            f := tot[A_Index] ? cnt[A_Index] / tot[A_Index] : 0
            d += (f - modele[A_Index]) ** 2
        }
        if (d < d1) {
            d2 := d1
            d1 := d
            meilleure := lettre
        } else if (d < d2) {
            d2 := d
        }
    }
    if (d1 < 4.5 && d2 - d1 > 2)
        return meilleure
    return ""
}

Mediane(t) {
    Loop t.Length - 1 {
        i := A_Index + 1
        v := t[i]
        j := i - 1
        while (j >= 1 && t[j] > v) {
            t[j + 1] := t[j]
            j -= 1
        }
        t[j + 1] := v
    }
    return t[(t.Length + 1) // 2]
}

; ---------- Appât ----------

; Le message "Attachez un appât..." est affiché en bas de l'écran
MessageAppat() {
    return CompterClairs(Photo("msgG", MSG_G_X1, MSG_Y1, MSG_G_X2, MSG_Y2)) >= 30
        && CompterClairs(Photo("msgD", MSG_D_X1, MSG_Y1, MSG_D_X2, MSG_Y2)) >= 30
}

; Tab, recherche de l'appât, clic droit dessus, puis Tab pour refermer
AttacherAppat() {
    if !InventaireOuvert() {
        Touche("Tab")
        Sleep Random(700, 1000)
        if !InventaireOuvert() {
            Info("Je ne vois pas l'inventaire après Tab")
            Journal("Appât : inventaire pas vu après Tab")
            return
        }
    }
    nom := APPATS[eau]
    Rechercher("inv", nom)
    Sleep 300
    if Detecte("inv") {                     ; la recherche a laissé l'appât en 1re case
        BougerVers(INV_X, INV_Y)
        Geste(40)
        if InventaireOuvert()
            Click "Right"
        Info("Appât attaché")
        Sleep Random(500, 900)
    } else {
        Info("Plus de " nom " dans l'inventaire", 4000)
    }
    ; on referme (2 essais : si la barre de recherche garde la main, le 1er Tab peut ne
    ; pas fermer l'inventaire)
    Loop 2 {
        if !InventaireOuvert()
            break
        FermerInventaire()
    }
    Sleep Random(300, 500)
}

; =============================================================================
;  Calibration : profil exact pour ta résolution, à partir des deux barres de poids
;  (inventaire à gauche, véhicule à droite). Il faut le coffre ouvert, avec un peu de
;  poids des deux côtés.
; =============================================================================

Calibrer() {
    global PROFIL
    Sleep 400                  ; le temps que le menu disparaisse de l'écran
    W := A_ScreenWidth, H := A_ScreenHeight
    y1 := Round(H * 0.15), y2 := Round(H * 0.215)    ; bande où se trouvent les barres de poids
    c := Capture(W, y2 - y1 + 1)
    c.Prendre(0, y1)
    g := TrouverBarre(c, 0, Round(W * 0.20))
    d := TrouverBarre(c, Round(W * 0.50), Round(W * 0.80))
    if (!g || !d || Abs(g.y - d.y) > 4) {
        SauverImage(c, "calibration_ratee")
        MsgBox "Calibration impossible.`n`nOuvre le coffre d'un véhicule (inventaire à gauche, véhicule à droite), avec un peu de poids des deux côtés, puis recommence.", "Calibrer", "Icon! T20"
        return false
    }
    fx := (d.x - g.x) / (1657 - 65)
    if (fx < 0.3 || fx > 3) {
        MsgBox "Calibration douteuse (échelle " Round(fx, 3) "), rien n'est enregistré.", "Calibrer", "Icon! T20"
        return false
    }
    ox := g.x - 65 * fx
    oy := (y1 + g.y) - 275 * fx
    sec := "profil_" W "x" H
    IniWrite Round(fx, 5), FICHIER_INI, sec, "fx"
    IniWrite Round(fx, 5), FICHIER_INI, sec, "fy"
    IniWrite Round(ox, 1), FICHIER_INI, sec, "ox"
    IniWrite Round(oy, 1), FICHIER_INI, sec, "oy"
    PROFIL := ChargerProfil()
    CalculerPositions()
    Journal("Calibration " W "x" H " : fx=" Round(fx, 4) " ox=" Round(ox, 1) " oy=" Round(oy, 1))
    MsgBox "Profil enregistré pour " W "x" H ".`nÉchelle " Round(fx, 3) ", décalage " Round(ox) " / " Round(oy) " px.", "Calibrer", "Iconi T10"
    return true
}

; Cherche dans la photo la barre rouge de poids entre x1 et x2 : la ligne rouge fine
; qui commence le plus à gauche. Renvoie {x, y} (y = milieu de la barre, dans la photo).
TrouverBarre(c, x1, x2) {
    meilleurX := 99999, lignes := []
    Loop c.h {
        y := A_Index - 1
        x := x1
        while (x < x2) {
            if EstBarre(c.Pixel(x, y)) {
                debut := x
                while (x < x2 && EstBarre(c.Pixel(x, y)))
                    x += 1
                if (x - debut >= 15) {
                    if (debut < meilleurX - 2) {
                        meilleurX := debut
                        lignes := [y]
                    } else if (Abs(debut - meilleurX) <= 2) {
                        lignes.Push(y)
                    }
                    break
                }
                continue           ; petit bout rouge isolé : on continue la ligne
            }
            x += 1
        }
    }
    ; une barre fait quelques pixels d'épaisseur, pas plus
    if (lignes.Length = 0 || lignes.Length > 14)
        return 0
    return {x: meilleurX, y: (lignes[1] + lignes[lignes.Length]) / 2}
}

EstBarre(p) {
    r := (p >> 16) & 0xFF, g := (p >> 8) & 0xFF
    return r >= 150 && r - g >= 60
}

; =============================================================================
;  PARTIE FARM : menu, récolte, transfo, vente
; =============================================================================

VERSION := "Macro v26"

; ---------- Quantités et poids ----------
POIDS_OBJET := 0.2      ; kg par objet (récolté comme transformé)
PAQUET      := 100      ; récolte et transfo : objets mis dans le véhicule à chaque dépôt
PRISE_BRUT  := 200      ; transfo : objets à transformer repris du véhicule
MARGE_KG    := 2        ; kg laissés libres dans l'inventaire quand le script calcule une prise

; ---------- Véhicule ----------
TOUCHE_COFFRE       := "l"    ; ouvre le coffre (le véhicule doit être déverrouillé)
TOUCHE_VERROU       := "u"    ; fin de transfo : verrouille le véhicule
TOUCHE_STOP_RECOLTE := "e"    ; fin de récolte : arrête de récolter ("" = aucune)
SEUIL_PLEIN         := 0.995  ; barre de poids du véhicule remplie à 99,5 % = plein

; Transfo : le nombre d'objets transformés ne bouge plus depuis ce temps (ms) = tout ce qui
; était dans ton inventaire est transformé (un lot arrive toutes les 6 s)
TRANSFO_FINIE := 20000

; Vente : une fois les objets pris et le coffre refermé (Tab), touches et pauses (ms), dans l'ordre
VENTE_ETAPES := [["e", 700], ["Enter", 680], ["Tab", 900], ["Enter", 1600]]

; ---------- Réglages retenus ----------
activite   := LireReglage("activite", "farm")
modeActuel := LireReglage("mode", "recolte")
if !(modeActuel = "recolte" || modeActuel = "transfo" || modeActuel = "vente")
    modeActuel := "recolte"
eau        := LireReglage("eau", "Mer")
if !APPATS.Has(eau)
    eau := "Mer"
appatAuto  := Integer(LireReglage("appatAuto", 0))
BRUT       := LireReglage("brut", "Ressources précieuses")
PRODUIT    := LireReglage("produit", "Pierres précieuses")
POIDS_MAX  := Number(LireReglage("poidsMax", 103))     ; poids max de ton inventaire (kg)
RAISON_ARRET := ""                                       ; pourquoi le farm s'est arrêté

if !MODE_TEST {
    Hotkey "Numpad7",    OuvrirMenu
    Hotkey "NumpadHome", OuvrirMenu
    Hotkey "Numpad9",    Basculer
    Hotkey "NumpadPgUp", Basculer
    Hotkey "Numpad8",    BasculerPanneau
    Hotkey "NumpadUp",   BasculerPanneau
    Etat("pause")
    if (LireReglage("dejaLance", 0) = 0)
        OuvrirMenu()
}

; Titre et ligne de détail du panneau
Resume() {
    if (activite = "peche")
        return {titre: "Pêche", detail: eau (appatAuto ? "   ·   appât auto" : "")}
    return {titre: Map("recolte", "Récolte", "transfo", "Transfo", "vente", "Vente")[modeActuel]
        , detail: (modeActuel = "recolte") ? BRUT : PRODUIT}
}

LancerCycle() {
    if (activite = "peche")
        SetTimer CyclePeche, -1
    else if (modeActuel = "transfo")
        SetTimer CycleTransfo, -1
    else if (modeActuel = "vente")
        SetTimer CycleVente, -1
    else
        SetTimer CycleRecolte, -1
}

; ================= Menu =================

OuvrirMenu(*) {
    global enMarche
    enMarche := false
    Etat("pause")

    g := Gui("+AlwaysOnTop -MinimizeBox", VERSION)
    g.SetFont("s10", "Segoe UI")
    g.Add("Text", "x16 y14 w260", "Que veux-tu faire ?")
    rbPeche := g.Add("Radio", "x16 y40 Group", "Pêche")
    rbFarm  := g.Add("Radio", "x130 y40", "Farm")

    g.Add("GroupBox", "x16 y70 w280 h96", "Pêche")
    txtEau  := g.Add("Text", "x32 y99", "Appât :")
    ddEau   := g.Add("DropDownList", "x88 y95 w192", ["Eau douce", "Mer", "Glaces", "Tropical", "Doigt sanglant"])
    cbAppat := g.Add("CheckBox", "x32 y132 w250", "Attacher l'appât tout seul")

    g.Add("GroupBox", "x16 y176 w280 h164", "Farm")
    rbRec := g.Add("Radio", "x32 y202 Group", "Récolte")
    rbTra := g.Add("Radio", "x120 y202", "Transfo")
    rbVen := g.Add("Radio", "x208 y202", "Vente")
    txtB  := g.Add("Text", "x32 y238", "Récolté :")
    edB   := g.Add("Edit", "x110 y234 w170", BRUT)
    txtP  := g.Add("Text", "x32 y272", "Transformé :")
    edP   := g.Add("Edit", "x110 y268 w170", PRODUIT)
    txtM  := g.Add("Text", "x32 y306", "Poids max :")
    edM   := g.Add("Edit", "x110 y302 w60", POIDS_MAX)
    txtKg := g.Add("Text", "x178 y306", "kg (inventaire)")

    g.Add("Text", "x16 y356", "Rythme :")
    ddRythme := g.Add("DropDownList", "x80 y352 w216", ["Rapide", "Naturel", "Tranquille"])
    btn    := g.Add("Button", "x16 y388 w280 h32 Default", "Valider")
    btnCal := g.Add("Button", "x16 y426 w280 h26", "Calibrer cet écran (coffre ouvert)")
    g.SetFont("s8 c808080", "Segoe UI")
    g.Add("Text", "x16 y460 w280", PROFIL.exact ? "Profil d'écran exact enregistré." : "Profil d'écran : proportionnel (pas calibré).")

    rbPeche.Value := (activite = "peche")
    rbFarm.Value  := (activite = "farm")
    try ddEau.Text := eau
    catch
        ddEau.Text := "Mer"
    cbAppat.Value := appatAuto
    rbRec.Value := (modeActuel = "recolte")
    rbTra.Value := (modeActuel = "transfo")
    rbVen.Value := (modeActuel = "vente")
    ddRythme.Value := RYTHME

    MajMenu(*) {
        p := rbPeche.Value
        for ctl in [txtEau, ddEau, cbAppat]
            ctl.Enabled := p
        for ctl in [rbRec, rbTra, rbVen, txtB, edB, txtP, edP, txtM, edM, txtKg]
            ctl.Enabled := !p
    }
    Valider(*) {
        global activite, modeActuel, eau, appatAuto, BRUT, PRODUIT, RYTHME, POIDS_MAX
        RYTHME     := ddRythme.Value
        activite   := rbPeche.Value ? "peche" : "farm"
        modeActuel := rbVen.Value ? "vente" : (rbTra.Value ? "transfo" : "recolte")
        eau        := ddEau.Text
        appatAuto  := cbAppat.Value
        if (Trim(edB.Value) != "")
            BRUT := Trim(edB.Value)
        if (Trim(edP.Value) != "")
            PRODUIT := Trim(edP.Value)
        m := StrReplace(Trim(edM.Value), ",", ".")
        if (IsNumber(m) && m > 0)
            POIDS_MAX := Number(m)
        for cle, val in Map("activite", activite, "mode", modeActuel, "eau", eau, "appatAuto", appatAuto
                , "brut", BRUT, "produit", PRODUIT, "poidsMax", POIDS_MAX, "rythme", RYTHME, "dejaLance", 1)
            EcrireReglage(cle, val)
        g.Destroy()
        Etat("pause")
        if (activite = "peche")
            MajCompteursPeche()
        else
            Compteurs("")                  ; pas de compteurs pour le farm
    }
    Calib(*) {
        g.Destroy()
        Calibrer()
        OuvrirMenu()
    }

    rbPeche.OnEvent("Click", MajMenu)
    rbFarm.OnEvent("Click", MajMenu)
    btn.OnEvent("Click", Valider)
    btnCal.OnEvent("Click", Calib)
    MajMenu()
    g.Show("w312 h482")
}

; ================= Coffre, arrêts, petites aides =================

FermerInventaire() {
    if !InventaireOuvert()
        return
    Touche("Tab")
    Loop 10 {
        Sleep 100
        if !InventaireOuvert()
            return
    }
}

; Ouvre le coffre avec L (3 essais). Le véhicule doit être déverrouillé.
OuvrirCoffre() {
    ; on revérifie avant d'appuyer sur L : si le coffre est en fait ouvert (écran masqué un
    ; instant), le L s'écrirait dans la barre de recherche ou la case de quantité
    Loop 3 {
        if CoffreOuvert()
            return true
        Sleep 250
    }
    if InventaireOuvert() {            ; inventaire seul (Tab) : on le ferme d'abord
        FermerInventaire()
        if InventaireOuvert()
            FermerInventaire()
        if InventaireOuvert() {        ; pas de L avec l'inventaire ouvert (il s'écrirait)
            Journal("L'inventaire ne se ferme pas, coffre pas ouvert")
            return false
        }
        Attendre(300, 500)
    }
    Loop 3 {
        Touche(TOUCHE_COFFRE)
        Attendre(900, 1300)
        if CoffreOuvert()
            return true
        if InventaireOuvert() {        ; c'est l'inventaire seul qui s'est ouvert
            Touche("Tab")
            Attendre(500, 700)
        } else if (A_Index < 3) {
            Attendre(600, 900)
        }
    }
    SauverImage(Photo("ecranbas", EcX(0), EcY(700), EcX(900), EcY(1440)), "coffre_inaccessible")
    Journal("Coffre inaccessible après 3 appuis sur L")
    return false
}

; Le coffre doit être ouvert ; sinon on l'ouvre. Après 3 échecs de suite, on arrête.
AssurerCoffre() {
    static echecs := 0
    if CoffreOuvert()
        return true
    Info("J'ouvre le coffre…", 1500)
    if OuvrirCoffre() {
        echecs := 0
        return true
    }
    echecs += 1
    if (echecs >= 3) {
        echecs := 0
        ArretFarm("Coffre inaccessible (véhicule verrouillé ou trop loin ?)")
    }
    Info("Le coffre ne s'ouvre pas (verrouillé ?), je réessaie…", 3000)
    Attendre(2500, 3500)
    return false
}

; Arrête le farm : referme l'inventaire si fermer, puis appuie sur toucheFin (E, U...)
; seulement si l'inventaire est bien fermé (sinon la lettre s'écrirait dans une recherche)
ArretFarm(texte, fermer := true, toucheFin := "") {
    global enMarche, enCours, RAISON_ARRET
    Loop 2 {
        if (!fermer || !InventaireOuvert())
            break
        FermerInventaire()
    }
    if (toucheFin != "") {
        if InventaireOuvert() {
            texte .= " (" toucheFin " pas appuyé : l'inventaire ne s'est pas fermé)"
        } else {
            Sleep 400
            Touche(toucheFin)
        }
    }
    Journal(texte)
    RAISON_ARRET := texte
    enMarche := false
    enCours := false
    Etat("arret")
    Info(texte, 0)
    Exit
}

; Empreinte du nombre affiché en haut à gauche de la 1re case : elle change dès que la
; quantité change (dépôt réussi, transfo qui avance...). 0 = case vide ou sans nombre.
SignatureQuantite(cote := "inv") {
    if SIMU
        return SIMU.SignatureQuantite(cote)
    zx := (cote = "inv") ? QUANT_INV_X : QUANT_VEH_X
    c := Photo("quant", zx, QUANT_Y, zx + Q_W - 1, QUANT_Y + Q_H - 1)
    h := 0
    Loop c.h {
        y := A_Index - 1
        Loop c.w {
            p := c.Pixel(A_Index - 1, y)
            r := (p >> 16) & 0xFF, g := (p >> 8) & 0xFF, b := p & 0xFF, mi := Min(r, g, b)
            if (mi >= 130 && Max(r, g, b) - mi < 60)
                h := Mod(h * 31 + y * 97 + A_Index, 1000000007)
        }
    }
    return h
}

; Après un glisser : la quantité de la case a-t-elle changé (ou la case s'est vidée) ?
QuantiteABouge(avant, cote := "inv") {
    Loop 8 {
        Sleep 120
        if (!Detecte(cote) || SignatureQuantite(cote) != avant)
            return true
    }
    return false
}

; Dépôt de 100 depuis l'inventaire : a-t-il vraiment eu lieu ? Pendant la récolte ou la
; transfo, le nombre de la case bouge tout seul (un lot arrive toutes les 6 s), donc il ne
; suffit pas. On regarde la barre de poids de l'inventaire : 100 objets = 20 kg en moins.
; Si la barre est illisible, on se rabat sur le nombre de la case.
DepotReussi(sig, fiAvant) {
    if (fiAvant < 0.02)
        return QuantiteABouge(sig)
    Loop 10 {
        Sleep 120
        if (fiAvant - RemplissageInventaire() >= 0.02)
            return true
    }
    return false
}

; Met 100 objets de la 1re case de l'inventaire dans le véhicule. true si c'est passé.
DeposerPaquet(cibleX, cibleY) {
    fi := RemplissageInventaire()
    sig := SignatureQuantite("inv")
    if !Glisser(INV_X, INV_Y, cibleX, cibleY, PAQUET)
        return false
    if !DepotReussi(sig, fi) {
        Journal("Dépôt de " PAQUET " refusé, véhicule à " Round(Max(0, RemplissageCamion()) * 100, 1) " %")
        return false
    }
    return true
}

; Glisse q objets de la 1re case du véhicule vers l'inventaire. Si le jeu refuse (il en reste
; moins de q), on prend tout ce qui reste, sans jamais dépasser q.
; Renvoie le nombre pris (0 = rien), -1 si l'inventaire s'est fermé.
PrendreDuVehicule(nom, q) {
    sig := SignatureQuantite("veh")
    if !Glisser(VEH_X, VEH_Y, INV2_X, INV2_Y, q)
        return -1
    if QuantiteABouge(sig, "veh")
        return q
    return ViderCase("veh", nom, q - 1)
}

; Déplace ce qui reste dans la 1re case sans connaître le nombre exact, sans dépasser maxi :
; on tente des quantités de plus en plus petites (64, 32, 16...). Si le jeu refuse, il n'y
; en avait pas assez ; si ça passe, exactement ce nombre est parti.
; Renvoie le nombre déplacé, ou -1 si l'inventaire s'est fermé en route.
ViderCase(cote, nom, maxi, cibleX := 0, cibleY := 0) {
    p := 1
    while (p * 2 <= maxi)
        p *= 2
    deplace := 0
    while (p >= 1) {
        if (deplace + p <= maxi) {
            if (!Detecte(cote) || !VerifierCase(cote, nom))
                break
            avant := SignatureQuantite(cote)
            if (cote = "inv")
                ok := Glisser(INV_X, INV_Y, cibleX, cibleY, p)
            else
                ok := Glisser(VEH_X, VEH_Y, INV2_X, INV2_Y, p)
            if !ok
                return -1
            if QuantiteABouge(avant, cote)
                deplace += p
        }
        p //= 2
    }
    return deplace
}

; Y a-t-il au moins 100 objets dans la 1re case ? Le nombre est lu 3 fois (il change
; pendant la récolte, une lecture au mauvais moment peut se tromper) :
;   1 = au moins 100, sûr (3 lectures à 3 chiffres ou plus, nombre assez large)
;   0 = moins de 100 (au moins une lecture à 1 ou 2 chiffres)
;  -1 = illisible : on ne dépose pas
AuMoins100(cote := "inv") {
    if SIMU
        return SIMU.AuMoins100(cote)
    zx := (cote = "inv") ? QUANT_INV_X : QUANT_VEH_X
    plus := 0, moins := 0
    Loop 3 {
        if (A_Index > 1)
            Sleep 150
        n := CompterChiffres(zx, QUANT_Y)
        if (n = 1 || n = 2)
            moins += 1
        else if (n >= 3 && DERNIER_RATIO >= 1.4)
            plus += 1
    }
    if (moins > 0)
        return 0
    return (plus = 3) ? 1 : -1
}

; L'inventaire doit être filtré pour avoir une case vide où déposer. Si ses deux premières
; cases sont occupées, c'est qu'il ne l'est pas : on tape la recherche (seulement dans ce cas).
FiltreInventaire(nom) {
    if (Detecte("inv", 1) && Detecte("inv", 2))
        Rechercher("inv", nom)
}

; ================= Poids =================
; Les barres rouges de poids sont précises à environ 0,15 kg (le texte "66 / 103 Kg", lui,
; est arrondi). Remplissage = poids / max.

; Part remplie d'une barre de poids (0 à 1), d'après son dernier pixel rouge. -1 si aucun rouge.
LireBarre(nom, x1, x2, y, deb, long) {
    c := Photo(nom, x1, y, x2, y)
    dernier := -1
    Loop c.w {
        if EstBarre(c.Pixel(A_Index - 1, 0))
            dernier := A_Index - 1
    }
    if (dernier < 0)
        return -1
    return Max(0, Min(1, (x1 + dernier + 1 - deb) / long))
}

RemplissageInventaire() {
    if SIMU
        return SIMU.Remplissage("inv")
    return Max(0, LireBarre("ibarre", IBARRE_X1, IBARRE_X2, BARRE_Y, IBARRE_DEB, IBARRE_LONG))
}

; Marche quelle que soit la capacité du véhicule (1000, 2000 kg...). -1 si on ne la voit pas.
RemplissageCamion() {
    if SIMU
        return SIMU.Remplissage("veh")
    return LireBarre("vbarre", VBARRE_X1, VBARRE_X2, VBARRE_Y, VBARRE_DEB, VBARRE_LONG)
}

VehiculePlein() => RemplissageCamion() >= SEUIL_PLEIN

; Objets d'un poids donné qu'on peut encore porter en gardant une marge :
; (max - poids actuel - marge) / poids. Ex. 66 kg sur 103 : (103 - 66 - 2) / 0,2 = 175.
ObjetsQuiRentrent(maxKg, remplissage, poids, marge) {
    libre := maxKg * (1 - remplissage) - marge
    return Max(0, Floor(libre / poids + 0.000001))     ; 0.000001 : 174,99999 doit donner 175
}

PlaceInventaire() => ObjetsQuiRentrent(POIDS_MAX, RemplissageInventaire(), POIDS_OBJET, MARGE_KG)

; ================= Pause quand tu n'es pas sur le jeu =================

; Petite pause qui s'interrompt si tu quittes le jeu (et s'arrête si tu appuies sur 9)
PauseJeu(mini, maxi) {
    global enCours
    if SIMU {
        SIMU.Avancer(Random(mini, maxi))
    } else {
        fin := A_TickCount + Random(mini, maxi)
        while (enMarche && JeuActif() && A_TickCount < fin)
            Sleep 50
    }
    if !enMarche {
        enCours := false
        Exit
    }
}

; Heure en ms (celle du jeu simulé pendant les tests)
Horloge() => SIMU ? SIMU.t : A_TickCount

; Tu n'es pas sur FiveM : le script ne fait rien et attend ton retour (le panneau affiche
; « En attente »). Renvoie true s'il a dû attendre (pour remettre les compteurs d'attente à zéro).
AttendreRetourJeu() {
    global enCours
    if JeuActif()
        return false
    while (enMarche && !JeuActif())
        Sleep 300
    if !enMarche {
        enCours := false
        Exit
    }
    Sleep 600                              ; le temps que le jeu se réaffiche
    return true
}

; ================= Récolte =================
; Coffre ouvert (L si besoin), recherche de l'objet récolté côté inventaire. Dès que la 1re
; case en contient 100, 100 partent dans le véhicule. En boucle, jusqu'à ce que la barre de
; poids du véhicule soit pleine : Tab, E (fin de la récolte) et pause.

CycleRecolte() {
    global enCours
    enCours := true
    filtre := false                    ; recherche tapée depuis l'ouverture du coffre ?
    deposes := 0, refus := 0
    while enMarche {
        AttendreRetourJeu()
        if !CoffreOuvert()
            filtre := false
        if !AssurerCoffre()
            continue
        ; E seulement si on a vraiment récolté : lancé avec un véhicule déjà plein, E
        ; lancerait une action au lieu d'arrêter la récolte
        if VehiculePlein()
            ArretFarm("Véhicule plein : récolte terminée", true, deposes ? TOUCHE_STOP_RECOLTE : "")
        if !filtre {
            Rechercher("inv", BRUT)        ; une seule fois par ouverture du coffre
            filtre := true
            Attendre(300, 450)
        }
        if (Detecte("inv") && VerifierCase("inv", BRUT) && AuMoins100("inv") = 1) {
            if DeposerPaquet(VEH_X, VEH_Y) {
                deposes += 1, refus := 0
            } else if (RemplissageCamion() >= 0.95) {
                ArretFarm("Véhicule plein (dépôt refusé) : récolte terminée", true, deposes ? TOUCHE_STOP_RECOLTE : "")
            } else if (++refus >= 3) {
                SauverImage(Photo("logcoffre", EcX(0), EcY(220), EcX(2560), EcY(520)), "depot_refuse")
                ArretFarm("3 dépôts refusés de suite : récolte arrêtée (regarde logs)")
            }
            continue
        }
        Info("J'attends d'en avoir " PAQUET, 2000)
        PauseJeu(1500, 2200)
    }
    enCours := false
}

; ================= Transfo =================
; Coffre ouvert (L si besoin), objets transformés recherchés à gauche, objets à transformer
; à droite. Le script en prend 200 (moins si ton poids ne le permet pas) ; dès que 100 sont
; transformés, il les remet dans le véhicule et en reprend 200.
; Fin : plus aucun objet à transformer dans le véhicule ET véhicule plein (tout est
; transformé et redéposé) : Tab, U (verrouillage) et pause. Si le véhicule n'est pas plein
; à la fin, rien n'est touché et le script se met en pause avec un message.

CycleTransfo() {
    global enCours
    enCours := true
    filtre := false                            ; recherches tapées depuis l'ouverture du coffre ?
    premiere := true                           ; au lancement, on prend tout de suite
    sigAvant := -1, dernierChangement := Horloge()
    sature := false                            ; dépôt refusé : le véhicule est plein
    echecs := 0                               ; prises ratées alors que plus rien ne bouge
    attentesFin := 0                           ; fins repoussées (objets pas transformés)
    while enMarche {
        if AttendreRetourJeu()
            dernierChangement := Horloge()
        if !CoffreOuvert()
            filtre := false
        if !AssurerCoffre()
            continue
        if !filtre {
            ; les objets transformés à gauche, ceux à transformer à droite (le véhicule
            ; contient les deux, il faut les séparer)
            Rechercher("inv", PRODUIT)
            Attendre(250, 400)
            Rechercher("veh", BRUT)
            filtre := true
            Attendre(300, 450)
        }
        ; 1. les objets transformés repartent 100 par 100. Dépôt refusé = véhicule plein :
        ; plus d'essai tant qu'on n'y a pas repris des objets à transformer
        deposes := 0
        while (!sature && enMarche && Detecte("inv") && VerifierCase("inv", PRODUIT) && AuMoins100("inv") = 1) {
            if !DeposerPaquet(VEH2_X, VEH2_Y) {
                sature := true
                break
            }
            deposes += 1
        }
        ; 2. le nombre d'objets transformés ne bouge plus depuis 20 s : tout est transformé
        sig := (Detecte("inv") && VerifierCase("inv", PRODUIT)) ? SignatureQuantite("inv") : 0
        if (sig != sigAvant || deposes > 0)
            sigAvant := sig, dernierChangement := Horloge()
        fini := (Horloge() - dernierChangement >= TRANSFO_FINIE)
        brutVehicule := Detecte("veh")
        ; 3. on reprend de quoi transformer : au lancement, après chaque dépôt, et quand
        ; tout est transformé (prise précédente plus petite que 100, à cause du poids)
        if (brutVehicule && (premiere || deposes > 0 || fini)) {
            premiere := false
            n := PrendreBrut()
            dernierChangement := Horloge()
            if (n > 0) {
                echecs := 0, sature := false   ; le véhicule a de la place à nouveau
                Journal("Transfo : " n " " BRUT " pris")
            } else if (n < 0 && fini && ++echecs >= 3) {
                ArretFarm("Rien ne se transforme et je ne peux plus rien prendre (hors de la zone ? inventaire plein ?) : transfo arrêtée", false)
            }
        }
        ; 4. plus rien à prendre dans le véhicule et tout est transformé : fin
        if (!brutVehicule && fini) {
            if (!FinTransfo() && ++attentesFin >= 3)
                ArretFarm("Des " BRUT " restent dans ton inventaire sans se transformer : transfo arrêtée", false)
            dernierChangement := Horloge()
        }
        if !brutVehicule
            Info("Plus rien à prendre, je laisse finir la transfo", 2000)
        PauseJeu(1800, 2400)
    }
    enCours := false
}

; Fin de transfo. On vérifie qu'il ne reste rien à transformer dans l'inventaire, on dépose
; les derniers objets transformés (moins de 100), puis les deux conditions : plus aucun objet
; à transformer dans le véhicule et véhicule plein. Si oui : Tab, U et pause.
; Renvoie false s'il reste des objets à transformer dans l'inventaire (on attend encore),
; true s'il en reste dans le véhicule (le cycle reprend).
FinTransfo() {
    Rechercher("inv", BRUT)
    Attendre(400, 600)
    reste := Detecte("inv")
    Rechercher("inv", PRODUIT)
    Attendre(400, 600)
    if reste {
        Journal("Fin de transfo : il reste des " BRUT " dans l'inventaire, j'attends")
        return false
    }
    ; même si la barre paraît pleine : à 99,5 %, il peut manquer une vingtaine d'objets
    if (Detecte("inv") && VerifierCase("inv", PRODUIT)) {
        n := ViderCase("inv", PRODUIT, PAQUET - 1, VEH2_X, VEH2_Y)
        Journal("Fin de transfo : " n " " PRODUIT " déposés")
    }
    ; recherche retapée : une case vide doit vraiment vouloir dire "plus rien à transformer"
    Rechercher("veh", BRUT)
    Attendre(400, 600)
    if Detecte("veh")
        return true
    if VehiculePlein()
        ArretFarm("Transfo terminée : véhicule plein et verrouillé", true, TOUCHE_VERROU)
    ArretFarm("Transfo terminée mais véhicule pas plein (" Round(Max(0, RemplissageCamion()) * 100) " %) : pas de verrouillage", false)
}

; Prend des objets à transformer : 200, ou moins si ton inventaire ne peut pas en porter
; autant. Renvoie le nombre pris, 0 s'il n'y en a plus dans le véhicule, -1 si rien n'a pu
; être pris (pas la place, recherche pas en place).
PrendreBrut() {
    FiltreInventaire(PRODUIT)              ; il faut une case vide pour les recevoir
    if !VerifierCase("veh", BRUT)
        return Detecte("veh") ? -1 : 0
    q := Min(PRISE_BRUT, PlaceInventaire())
    if (q <= 0)
        return -1
    n := PrendreDuVehicule(BRUT, q)
    return (n > 0) ? n : (Detecte("veh") ? -1 : 0)
}

; ================= Vente =================
; Coffre ouvert (L si besoin), objets transformés recherchés des deux côtés. Le script lit
; ton poids sur la barre de l'inventaire et prend d'un coup ce qui rentre en gardant 2 kg
; libres. Puis Tab (on ressort du coffre) et la suite des touches de vente. En boucle,
; jusqu'à ce que le véhicule n'en ait plus.

CycleVente() {
    global enCours
    enCours := true
    while enMarche {
        AttendreRetourJeu()
        if !AssurerCoffre()
            continue
        ; l'inventaire filtré laisse une case vide pour recevoir les objets
        Rechercher("veh", PRODUIT)
        Attendre(250, 400)
        Rechercher("inv", PRODUIT)
        Attendre(300, 450)
        dejaLa := Detecte("inv")               ; objets transformés déjà dans l'inventaire
        if (!Detecte("veh") && !dejaLa)
            ArretFarm("Plus de " PRODUIT " dans le véhicule : vente terminée")
        q := PlaceInventaire()
        pris := 0
        if (q > 0 && Detecte("veh") && VerifierCase("veh", PRODUIT))
            pris := Max(0, PrendreDuVehicule(PRODUIT, q))
        Journal("Vente : " pris " " PRODUIT " pris (place pour " q ")")
        if (pris = 0 && !dejaLa) {
            SauverImage(Photo("logcoffre", EcX(0), EcY(220), EcX(2560), EcY(520)), "vente_rien_pris")
            ArretFarm("Rien pu prendre (place pour " q " d'après ton poids) : vérifie le poids max (menu 7). Vente arrêtée")
        }
        ; on ressort du coffre (2 essais), puis E et la suite, seulement si c'est bien fermé
        Loop 2 {
            if !InventaireOuvert()
                break
            FermerInventaire()
        }
        if InventaireOuvert()
            ArretFarm("Le coffre ne se referme pas : vente arrêtée avant d'appuyer sur E")
        Attendre(400, 600)
        for etape in VENTE_ETAPES {
            Touche(etape[1])
            Attendre(etape[2], etape[2] + 150)
        }
    }
    enCours := false
}

; ================= Lecture de la quantité d'une case =================
; Compte les chiffres du nombre en haut à gauche d'une case (3 chiffres ou plus = au moins 100).
; Modèles de chiffres tirés de tes captures, pour chaque hauteur de texte possible.
DONNEES_CHIFFRES := "
(
6 0 01110/11111/11011/11011/11111/01110
6 1 010/111/011/011/011/000
6 2 0110/1110/0011/0110/1111/1110
6 3 1110/1110/0110/0011/1111/0110
6 4 00100/01101/01011/11111/11111/00010
6 5 0110/1110/1110/0111/1111/0110
6 6 0010/0100/1111/1011/1111/0110
6 7 1110/1111/0111/0111/0101/0100
6 8 0110/1111/0111/1111/1111/0110
6 9 0110/1111/1011/1110/0110/0100
7 0 011110/011110/110011/110011/110011/011110/001110
7 1 0110/1110/0011/0011/0011/0011/0010
7 2 01110/11110/10011/00110/01100/11111/11110
7 3 11110/11111/00110/00110/10011/11111/01110
7 4 001000/001001/011001/110111/111111/111110/000110
7 5 01110/11111/11100/11111/00011/11111/01110
7 6 00110/01100/01100/11111/10011/11111/01110
7 7 11110/11111/00111/01111/01101/01101/01000
7 8 01110/11111/11011/01111/11011/11111/01110
7 9 01110/11111/10011/11111/01110/01100/01000
8 0 0011100/0111110/1110111/1100011/1100011/1110111/0111110/0001000
8 1 0110/1110/0011/0011/0011/0011/0011/0000
8 2 011100/111110/100110/001111/001100/111001/111110/111110
8 3 111110/111111/001100/001110/000110/110011/111110/001100
8 4 0001000/0011001/0111001/0110111/1111111/1111111/0111110/0000100
8 5 011110/111111/111000/111110/011111/110011/111110/001100
8 6 001100/001100/011100/111111/110111/110111/111110/001100
8 7 111110/111111/001111/001111/011111/011011/011001/010000
8 8 011110/111111/110111/011110/111111/110011/111111/001100
8 9 011100/111111/110011/111111/111111/001101/011000/010000
9 0 00111000/01111110/11100111/11000111/11000111/11000111/11100111/01111110/00011000
9 1 0000/1110/0111/0011/0011/0011/0011/0011/0000
9 2 0011100/1111110/1100110/0000111/0001110/0011100/0111001/1111110/0111110
9 3 0111100/1111111/0001100/0001100/0011110/1000011/1100011/1111110/0011100
9 4 00000000/00111001/00110001/01110001/01101101/11111111/11111111/01111100/00000000
9 5 0011110/0111111/0110000/0111000/0111110/0000011/0100011/1111110/0011100
9 6 0001000/0011100/0111000/0111101/1111111/1100111/1100111/1111110/0011100
9 7 1111100/1111111/0001111/0011111/0011111/0111011/0111011/0110001/0100000
9 8 0011100/0111110/0110011/0110110/0111110/1110011/1100011/0111111/0011100
9 9 0011100/1111111/1100111/1100011/1111111/1111101/1011101/0011000/0010000
10 0 00111000/01111100/01111110/11000111/11000111/11000111/11000111/11111110/01111100/00011000
10 1 00000/11110/11110/00111/00111/00111/00111/00111/00110/00000
10 2 00111000/01111100/11111110/00001111/00011111/00011100/00111000/11111101/11111110/01111100
10 3 00111100/11111111/11111100/00011100/00011110/10011110/10000111/11111111/00111110/00011000
10 4 00000000/00111000/00111001/01110001/01101111/01001101/11111111/11111111/00001100/00000000
10 5 00111100/01111111/01111100/01110000/01111100/01111111/00000111/11111111/01111100/00011000
10 6 00000000/00011100/00111000/01111101/01111111/11101111/11101111/11111111/01111100/00011000
10 7 11111100/11111111/11111111/00011111/00011011/00011111/00110111/00110011/01110011/00100000
10 8 00011000/00111110/01111111/01111110/00111110/01111110/11100111/11111111/00111110/00011000
10 9 00011000/01111110/11111111/11100111/11111111/11111111/10111101/10011000/00110000/00100000
11 0 000111000/001111100/011111110/111101111/111000111/111000111/111000111/111101111/011111110/001111100/000010000
11 1 000000/111110/111110/001111/000111/000111/000111/000111/000111/000110/000000
11 2 00111000/01111100/11111110/11101110/00001111/00011100/00111000/01110001/11111111/11111110/01111100
11 3 00111100/11111111/11111111/00011100/00011100/00011110/10000111/11100111/11111110/00111110/00011000
11 4 000000000/000110000/000110001/001110001/001101001/011101101/111111111/111111111/011111101/000001100/000001000
11 5 00111100/01111111/01111111/01100000/01110000/01111110/00000111/01100111/11111111/01111100/00011000
11 6 00000000/00011100/00011000/00110000/01111101/11111111/11101111/11101111/11111111/01111100/00011000
11 7 11111100/11111111/11111111/00011111/00011111/00011011/00110111/00110111/01110011/01110011/00100000
11 8 00011000/00111110/01111111/01100111/01111110/01111110/11100111/11100111/11111111/00111110/00011000
11 9 00011000/01111110/11111111/11101111/11100111/11111111/10111101/10011101/10111000/00110000/00100000
12 0 0001111000/0011111100/0111111110/1111001111/1110000111/1110000111/1110000111/1110000111/1111001111/0111111110/0011111100/0000110000
12 1 000000/111110/111110/001111/000111/000111/000111/000111/000111/000111/000110/000000
12 2 001111000/011111100/111111110/111001110/000001111/000011111/000111100/001111000/011110001/111111111/111111110/011111100
12 3 001111100/111111111/111111111/000011100/000011100/000111110/100011110/100000111/111000111/111111110/001111110/000111000
12 4 0000000000/0001110000/0001110001/0011100001/0011101001/0111011111/0110011101/1111111111/1111111111/0111111101/0000011100/0000001000
12 5 001111100/011111111/011111111/011100000/011110000/011111100/011111111/000000111/011000111/111111111/011111100/000111000
12 6 000010000/000111100/000111000/001110000/011111101/011111111/111001111/111001111/111001111/111111111/011111100/000111000
12 7 111111100/111111111/111111111/000011111/000111111/000111011/000111111/001110111/001110111/011110011/011100011/001000000
12 8 000111000/001111110/011111111/011100111/011101110/001111110/011111110/111100111/111000111/111111111/001111110/000111000
12 9 000111000/011111110/111111111/111001111/111000111/111101111/111111111/101111101/100111101/101111000/001110000/001100000
13 0 00011111000/00111111100/01111111110/11110001111/11100000111/11100000111/11100000111/11100000111/11100000111/11110001111/01111111110/00111111100/00001110000
13 1 000000/111110/111110/001111/000111/000111/000111/000111/000111/000111/000111/000110/000000
13 2 0011111000/0111111100/1111111110/1110001110/0000001111/0000111111/0001111100/0001111100/0011111000/0111110001/1111111111/1111111110/0111111100
13 3 0011111100/1111111111/1111111111/0000111100/0000111100/0001111110/1000111110/1000111110/1000000111/1110000111/1111111110/0011111110/0001111000
13 4 00000000000/00011110000/00011110001/00111000001/00111001001/01110111111/01100111101/01100111101/11111111111/11111111111/01111111101/00000111100/00000001000
13 5 0011111100/0111111111/0111111111/0111000000/0111110000/0111111100/0111111111/0111111111/0000000111/0110000111/1111111111/0111111100/0001111000
13 6 0000110000/0001111100/0001111000/0011110000/0111111101/0111111111/1110001111/1110001111/1110001111/1110001111/1111111111/0111111100/0001111000
13 7 1111111100/1111111111/1111111111/0000111111/0001111111/0001111011/0001111111/0001111111/0011110111/0011110111/0111110011/0111000011/0010000000
13 8 0001111000/0011111110/0111111111/0111000111/0111001110/0011111110/0111111110/0111111110/1111000111/1110000111/1111111111/0011111110/0001111000
13 9 0001111000/0111111110/1111111111/1110001111/1110000111/1111001111/1111111111/1111111111/1011111101/1001111101/1011111000/0011110000/0011000000
14 0 000011110000/001111111100/011111111110/111110011111/111110011111/111100001111/111100001111/111100001111/111100001111/111110011111/011111111110/011111111110/001111111100/000001100000
14 1 0000000/1111110/1111110/0011111/0011111/0001111/0001111/0001111/0001111/0001111/0001111/0001111/0001110/0000000
14 2 0011111000/0111111100/1111111110/1110001110/1110001110/0000001111/0000111111/0001111100/0011111000/0111110001/1111111111/1111111111/1111111110/0111111100
14 3 0011111100/1111111111/1111111111/0000111100/0000111100/0000111100/0001111110/1000111110/1000000111/1110000111/1111111110/1111111110/0011111110/0001111000
14 4 000000000000/000011100000/000011100001/001111000001/001111000001/001111010001/011110111111/011100111101/111111111111/111111111111/011111111101/011111111101/000000111100/000000010000
14 5 0011111100/0111111111/0111111111/0111000000/0111000000/0111110000/0111111100/0111111111/0000000111/0110000111/1111111111/1111111111/0111111100/0001111000
14 6 0000110000/0001111100/0001111000/0011110000/0011110000/0111111101/0111111111/1110001111/1110001111/1110001111/1111111111/1111111111/0111111100/0001111000
14 7 1111111100/1111111111/1111111111/0000111111/0000111111/0001111111/0001111011/0001111111/0011110111/0011110111/0111110011/0111110011/0111000011/0010000000
14 8 0001111000/0011111110/0111111111/0111000111/0111000111/0111001110/0011111110/0111111110/1111000111/1110000111/1111111111/1111111111/0011111110/0001111000
14 9 0001111000/0111111110/1111111111/1110001111/1110001111/1110000111/1111001111/1111111111/1011111101/1001111101/1011111000/1011111000/0011110000/0011000000
15 0 000011110000/001111111100/011111111110/011111111110/111110011111/111100001111/111100001111/111100001111/111100001111/111100001111/111110011111/011111111110/001111111100/001111111100/000001100000
15 1 00000000/11111110/11111110/11111110/00011111/00001111/00001111/00001111/00001111/00001111/00001111/00001111/00001110/00001110/00000000
15 2 00111110000/01111111100/11111111110/11111111110/11110011110/00000011111/00000111111/00001111100/00001111100/00111110000/01111100001/11111111111/11111111110/11111111110/01111111100
15 3 00111111100/11111111111/11111111111/11111111111/00000111100/00000111100/00001111110/10000111110/10000111110/10000001111/11110001111/11111111110/00111111110/00111111110/00001110000
15 4 000000000000/000011100000/000011100001/000011100001/001111000001/001111010001/011110111111/011100111101/011100111101/111111111111/111111111111/011111111101/000000111100/000000111100/000000010000
15 5 00111111100/01111111111/01111111111/01111111111/01111000000/01111100000/01111111100/01111111111/01111111111/00000001111/01110001111/11111111111/01111111100/01111111100/00001110000
15 6 00000100000/00001111100/00001110000/00001110000/00111100000/01111111101/01111111111/11110011111/11110011111/11110011111/11110011111/11111111111/01111111100/01111111100/00001110000
15 7 11111111100/11111111111/11111111111/11111111111/00000111111/00001111111/00001110011/00001111111/00001111111/00111101111/00111101111/01111100011/01111000011/01111000011/00110000000
15 8 00001110000/00111111110/01111111111/01111111111/01111001111/01111011110/00111111110/01111111110/01111111110/11111001111/11110001111/11111111111/00111111110/00111111110/00001110000
15 9 00001110000/01111111110/11111111111/11111111111/11110011111/11110001111/11111011111/11111111111/11111111111/10111111101/10001111101/10111110000/00111100000/00111100000/00111000000
16 0 0000111110000/0001111111000/0001111111000/0111111111110/1111100011111/1111000001111/1111000001111/1111000001111/1111000001111/1111000001111/1111000001111/1111100011111/0111111111110/0001111111000/0001111111000/0000011100000
16 1 00000000/11111110/11111110/11111110/00011111/00001111/00001111/00001111/00001111/00001111/00001111/00001111/00001111/00001110/00001110/00000000
16 2 000111110000/011111111000/011111111000/111111111110/111100011110/000000011111/000000011111/000001111111/000011111000/000111110000/000111110000/011111100001/111111111111/111111111110/111111111110/011111111000
16 3 000111111000/111111111111/111111111111/111111111111/000001111000/000001111000/000001111000/000011111110/100001111110/100000001111/100000001111/111100001111/111111111110/000111111110/000111111110/000011110000
16 4 0000000000000/0000111100000/0000111100000/0000111100001/0001110000001/0001110010001/0001110010001/0111101111111/0111001111001/1111111111111/1111111111111/1111111111111/0111111111001/0000001111000/0000001111000/0000000010000
16 5 000111111000/011111111111/011111111111/011111111111/011110000000/011111100000/011111100000/011111111000/011111111111/000000001111/000000001111/011100001111/111111111111/011111111000/011111111000/000011110000
16 6 000001100000/000011111000/000011111000/000011110000/000111100000/011111111001/011111111001/011111111111/111100011111/111100011111/111100011111/111100011111/111111111111/011111111000/011111111000/000011110000
16 7 111111111000/111111111111/111111111111/111111111111/000001111111/000011111111/000011111111/000011110111/000011111111/000111101111/000111101111/000111101111/011111100111/011110000111/011110000111/000100000000
16 8 000011110000/000111111110/000111111110/011111111111/011110001111/011110011110/011110011110/000111111110/011111111110/111110001111/111110001111/111100001111/111111111111/000111111110/000111111110/000011110000
16 9 000011110000/011111111110/011111111110/111111111111/111100011111/111100001111/111100001111/111110011111/111111111111/100111111001/100111111001/100011111001/100111110000/000111100000/000111100000/000110000000
)"

CHIFFRES := Map()
Loop Parse DONNEES_CHIFFRES, "`n", "`r" {
    if (A_LoopField = "")
        continue
    champs := StrSplit(A_LoopField, " ")
    hh := Integer(champs[1])
    if !CHIFFRES.Has(hh)
        CHIFFRES[hh] := Map()
    lignes := []
    for ligne in StrSplit(champs[3], "/") {
        bits := []
        Loop Parse ligne
            bits.Push(Integer(A_LoopField))
        lignes.Push(bits)
    }
    CHIFFRES[hh][champs[2]] := {w: lignes[1].Length, rows: lignes}
}

CompterChiffres(zx, zy) {
    capQ := Photo("quant", zx, zy, zx + Q_W - 1, zy + Q_H - 1)

    ; pixels clairs et gris = encre
    m := []
    Loop Q_H {
        j := A_Index - 1
        lig := []
        Loop Q_W {
            p := capQ.Pixel(A_Index - 1, j)
            r := (p >> 16) & 0xFF, g := (p >> 8) & 0xFF, b := p & 0xFF
            mi := Min(r, g, b)
            lig.Push((mi >= 130 && Max(r, g, b) - mi < 60) ? 1 : 0)
        }
        m.Push(lig)
    }
    col := []
    Loop Q_W {
        i := A_Index, n := 0
        Loop Q_H
            n += m[A_Index][i]
        col.Push(n)
    }

    ; premier groupe de colonnes à gauche (le poids, à droite, est ignoré). Un groupe de
    ; moins de 5 pixels de haut n'est pas un chiffre (coin clair d'une bordure de couleur) :
    ; on passe au suivant.
    global DERNIER_RATIO
    depart := 1
    Loop {
        x1 := 0
        i := depart
        while (i <= Q_W) {
            if col[i] {
                x1 := i
                break
            }
            i += 1
        }
        if !x1 {
            DERNIER_RATIO := 0
            return 0
        }
        x2 := x1
        i := x1
        while (i < Q_W) {
            i += 1
            if col[i] {
                if (i - x2 > Q_GAP)
                    break
                x2 := i
            }
        }
        y1 := 0, y2 := 0
        Loop Q_H {
            j := A_Index
            c := x1
            while (c <= x2) {
                if m[j][c] {
                    if !y1
                        y1 := j
                    y2 := j
                    break
                }
                c += 1
            }
        }
        if (y2 - y1 + 1 >= 5)
            break
        depart := x2 + 1
    }
    h := y2 - y1 + 1, W := x2 - x1 + 1
    DERNIER_RATIO := W / h

    ; masque recadré sur le nombre
    rec := [], colRec := []
    Loop h {
        j := y1 + A_Index - 1
        lig := []
        c := x1
        while (c <= x2) {
            lig.Push(m[j][c])
            c += 1
        }
        rec.Push(lig)
    }
    Loop W {
        i := A_Index, n := 0
        Loop h
            n += rec[A_Index][i]
        colRec.Push(n)
    }

    modeles := CHIFFRES[Min(Max(h, 6), 16)]

    ; découpage optimal du nombre en chiffres (programmation dynamique)
    INF := -999999
    best := [], prev := []
    Loop W + 4 {
        best.Push(INF)
        prev.Push(-1)
    }
    best[1] := 0
    x := 0
    while (x <= W) {
        if (best[x + 1] = INF) {
            x += 1
            continue
        }
        for d, t in modeles {
            tw := t.w, s := 0
            hm := Min(h, t.rows.Length)
            Loop hm {
                lt := t.rows[A_Index], lm := rec[A_Index]
                Loop tw {
                    xi := x + A_Index
                    v := (xi <= W) ? lm[xi] : 0
                    s += (v = lt[A_Index]) ? 1 : -1
                }
            }
            for g in [-1, 0, 1] {
                nx := Max(x + 1, Min(W + 3, x + tw + g))
                pen := 0
                c := x + tw
                while (c < Min(nx, W)) {
                    pen += colRec[c + 1]
                    c += 1
                }
                sc := best[x + 1] + s - 2 * pen - 6
                if (sc > best[nx + 1]) {
                    best[nx + 1] := sc
                    prev[nx + 1] := x
                }
            }
        }
        x += 1
    }
    fin := Max(0, W - 1)
    k := Max(0, W - 1)
    while (k <= W + 3) {
        if (best[k + 1] > best[fin + 1])
            fin := k
        k += 1
    }
    n := 0
    k := fin
    while (k > 0 && prev[k + 1] >= 0) {
        k := prev[k + 1]
        n += 1
    }
    return n
}
