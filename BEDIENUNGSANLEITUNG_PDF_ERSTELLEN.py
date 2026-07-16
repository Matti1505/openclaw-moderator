# -*- coding: utf-8 -*-
"""Erzeugt die vollständige Chatwächter-Anleitung immer komplett neu."""
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate, Frame, Image, KeepTogether, PageBreak, PageTemplate,
    Paragraph, Spacer, Table, TableStyle
)
from reportlab.platypus.tableofcontents import TableOfContents


ROOT = Path(__file__).resolve().parent
TARGET = ROOT / "CHATWAECHTER_BEDIENUNGSANLEITUNG.pdf"
DASHBOARD_IMAGE = ROOT / "manual_assets" / "dashboard.png"
VERSION = "4.6"
VERSION_DATE = "15.07.2026"

NAVY = colors.HexColor("#041426")
NAVY_2 = colors.HexColor("#082944")
BLUE = colors.HexColor("#167DF5")
CYAN = colors.HexColor("#00C8F5")
TEXT = colors.HexColor("#172B3E")
MUTED = colors.HexColor("#587087")
LINE = colors.HexColor("#C9D7E4")
PALE = colors.HexColor("#EEF6FC")
GREEN = colors.HexColor("#1B9B61")
YELLOW = colors.HexColor("#D28A00")
RED = colors.HexColor("#D42D49")


def register_fonts():
    regular = Path(r"C:\Windows\Fonts\segoeui.ttf")
    bold = Path(r"C:\Windows\Fonts\segoeuib.ttf")
    if regular.exists() and bold.exists():
        pdfmetrics.registerFont(TTFont("Manual", str(regular)))
        pdfmetrics.registerFont(TTFont("Manual-Bold", str(bold)))
        return "Manual", "Manual-Bold"
    return "Helvetica", "Helvetica-Bold"


FONT, FONT_BOLD = register_fonts()


class ManualDocument(BaseDocTemplate):
    def __init__(self, filename, **kwargs):
        super().__init__(filename, **kwargs)
        frame = Frame(16*mm, 17*mm, A4[0]-32*mm, A4[1]-34*mm, id="content")
        self.addPageTemplates(PageTemplate(id="manual", frames=frame, onPage=self.draw_page))

    def draw_page(self, canvas, doc):
        w, h = A4
        if doc.page == 1:
            canvas.saveState()
            canvas.setFillColor(NAVY)
            canvas.rect(0, 0, w, h, fill=1, stroke=0)
            canvas.setFillColor(CYAN)
            canvas.circle(w-28*mm, h-27*mm, 5*mm, fill=0, stroke=1)
            canvas.setLineWidth(2)
            canvas.line(w-34*mm, h-27*mm, w-22*mm, h-27*mm)
            canvas.line(w-28*mm, h-33*mm, w-28*mm, h-21*mm)
            canvas.restoreState()
            return
        canvas.saveState()
        canvas.setStrokeColor(LINE)
        canvas.line(16*mm, h-13*mm, w-16*mm, h-13*mm)
        canvas.setFont(FONT_BOLD, 8)
        canvas.setFillColor(NAVY_2)
        canvas.drawString(16*mm, h-10*mm, "CHATWÄCHTER · BEDIENUNGSANLEITUNG")
        canvas.setFont(FONT, 8)
        canvas.setFillColor(MUTED)
        canvas.drawRightString(w-16*mm, h-10*mm, f"Version {VERSION} · {VERSION_DATE}")
        canvas.line(16*mm, 13*mm, w-16*mm, 13*mm)
        canvas.drawString(16*mm, 8.5*mm, "Chatwächter Control Center 2026")
        canvas.drawRightString(w-16*mm, 8.5*mm, f"Seite {doc.page}")
        canvas.restoreState()

    def afterFlowable(self, flowable):
        if isinstance(flowable, Paragraph):
            style = flowable.style.name
            if style in ("H1", "H2"):
                level = 0 if style == "H1" else 1
                text = flowable.getPlainText()
                key = f"h-{self.seq.nextf('heading')}"
                self.canv.bookmarkPage(key)
                self.canv.addOutlineEntry(text, key, level=level, closed=False)
                self.notify("TOCEntry", (level, text, self.page, key))


styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="CoverTitle", fontName=FONT_BOLD, fontSize=31, leading=36, textColor=colors.white, spaceAfter=8*mm))
styles.add(ParagraphStyle(name="CoverSub", fontName=FONT, fontSize=16, leading=22, textColor=colors.HexColor("#BCEFFF"), spaceAfter=5*mm))
styles.add(ParagraphStyle(name="CoverText", fontName=FONT, fontSize=10.5, leading=16, textColor=colors.HexColor("#D9EAF7")))
styles.add(ParagraphStyle(name="H1", fontName=FONT_BOLD, fontSize=20, leading=24, textColor=NAVY_2, spaceBefore=4*mm, spaceAfter=4*mm, keepWithNext=True))
styles.add(ParagraphStyle(name="H2", fontName=FONT_BOLD, fontSize=13, leading=17, textColor=BLUE, spaceBefore=5*mm, spaceAfter=2*mm, keepWithNext=True))
styles.add(ParagraphStyle(name="Body", fontName=FONT, fontSize=9.5, leading=14, textColor=TEXT, spaceAfter=2.4*mm))
styles.add(ParagraphStyle(name="Small", fontName=FONT, fontSize=8, leading=11, textColor=MUTED, spaceAfter=1.5*mm))
styles.add(ParagraphStyle(name="ManualBullet", fontName=FONT, fontSize=9.3, leading=13.5, leftIndent=5*mm, firstLineIndent=-3.5*mm, bulletIndent=0, textColor=TEXT, spaceAfter=1.2*mm))
styles.add(ParagraphStyle(name="StepNo", fontName=FONT_BOLD, fontSize=12, leading=16, textColor=colors.white, alignment=TA_CENTER))
styles.add(ParagraphStyle(name="Box", fontName=FONT, fontSize=9.2, leading=13.5, textColor=TEXT))
styles.add(ParagraphStyle(name="TableHead", fontName=FONT_BOLD, fontSize=8.4, leading=11, textColor=colors.white))
styles.add(ParagraphStyle(name="TableCell", fontName=FONT, fontSize=8.2, leading=11, textColor=TEXT))
styles.add(ParagraphStyle(name="TableCellBold", fontName=FONT_BOLD, fontSize=8.2, leading=11, textColor=TEXT))


def P(text, style="Body"):
    return Paragraph(text, styles[style])


def H1(text):
    return Paragraph(text, styles["H1"])


def H2(text):
    return Paragraph(text, styles["H2"])


def bullet(text):
    return Paragraph("• " + text, styles["ManualBullet"])


def box(text, color=BLUE, background=PALE):
    t = Table([[P(text, "Box")]], colWidths=[174*mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,-1), background),
        ("BOX", (0,0), (-1,-1), 0.6, color),
        ("LINEBEFORE", (0,0), (0,-1), 4, color),
        ("LEFTPADDING", (0,0), (-1,-1), 5*mm),
        ("RIGHTPADDING", (0,0), (-1,-1), 4*mm),
        ("TOPPADDING", (0,0), (-1,-1), 3.5*mm),
        ("BOTTOMPADDING", (0,0), (-1,-1), 3.5*mm),
    ]))
    return t


def data_table(headers, rows, widths=None):
    data = [[P(h, "TableHead") for h in headers]]
    for row in rows:
        data.append([P(str(cell), "TableCellBold" if i == 0 else "TableCell") for i, cell in enumerate(row)])
    table = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,0), NAVY_2),
        ("GRID", (0,0), (-1,-1), 0.45, LINE),
        ("VALIGN", (0,0), (-1,-1), "TOP"),
        ("ROWBACKGROUNDS", (0,1), (-1,-1), [colors.white, PALE]),
        ("LEFTPADDING", (0,0), (-1,-1), 2.5*mm),
        ("RIGHTPADDING", (0,0), (-1,-1), 2.5*mm),
        ("TOPPADDING", (0,0), (-1,-1), 2.1*mm),
        ("BOTTOMPADDING", (0,0), (-1,-1), 2.1*mm),
    ]))
    return table


def step(number, title, text):
    n = Table([[P(str(number), "StepNo")]], colWidths=[9*mm], rowHeights=[9*mm])
    n.setStyle(TableStyle([("BACKGROUND",(0,0),(-1,-1),BLUE),("VALIGN",(0,0),(-1,-1),"MIDDLE")]))
    content = P(f"<b>{title}</b><br/>{text}")
    t = Table([[n, content]], colWidths=[12*mm, 162*mm])
    t.setStyle(TableStyle([("VALIGN",(0,0),(-1,-1),"TOP"),("LEFTPADDING",(0,0),(-1,-1),0),("RIGHTPADDING",(0,0),(-1,-1),2*mm),("TOPPADDING",(0,0),(-1,-1),1.5*mm),("BOTTOMPADDING",(0,0),(-1,-1),2.5*mm)]))
    return t


def build_story():
    s = []
    # Umschlag
    s += [Spacer(1, 48*mm), P("CHATWÄCHTER", "CoverTitle"), P("Professionelle Bedienungsanleitung", "CoverSub"),
          P("Für Einsteiger und Moderatoren<br/>Start · Liveüberwachung · Regeln · automatische Aktionen · Protokolle · Fehlerhilfe", "CoverText"),
          Spacer(1, 26*mm), P(f"Vollständige Neuausgabe {VERSION}<br/>Stand {VERSION_DATE}<br/>Chatwächter Control Center 2026", "CoverText"), PageBreak()]

    s += [H1("Inhaltsverzeichnis")]
    toc = TableOfContents()
    toc.levelStyles = [
        ParagraphStyle(name="TOC1", fontName=FONT_BOLD, fontSize=10, leading=15, leftIndent=0, textColor=NAVY_2, spaceBefore=2*mm),
        ParagraphStyle(name="TOC2", fontName=FONT, fontSize=8.8, leading=13, leftIndent=7*mm, textColor=MUTED),
    ]
    s += [toc, PageBreak()]

    s += [H1("1 · Schnellstart")]
    s += [step(1,"Control Center starten","Doppelklicke auf <b>CHATWAECHTER_EXAKT_40_STARTEN.vbs</b>. Nicht die Python-Datei einzeln öffnen."),
          step(2,"Status prüfen","Oben müssen <b>BEREIT</b> und <b>Verbunden</b> erscheinen. Gelb bedeutet: korrekt verbunden, aber kein Stream aktiv."),
          step(3,"Stream suchen lassen","Der Wächter sucht alle 45 Sekunden. Mit <b>Jetzt suchen</b> kannst du sofort zusätzlich prüfen."),
          step(4,"Livebetrieb beobachten","Bei einem Treffer wechseln Status und Suchkreis auf grün. Video und offizieller YouTube-Livechat werden geladen."),
          step(5,"Nach dem Stream prüfen","Öffne <b>PROTOKOLL</b>, kontrolliere Regeltreffer und exportiere bei Bedarf CSV, JSON oder PDF.")]
    s += [box("<b>Merksatz:</b> BEREIT ist ein guter Zustand. OFFLINE ist ein Fehlerzustand.", GREEN, colors.HexColor("#EAF8F1"))]

    s += [H1("2 · Voraussetzungen und Programmstart")]
    s += [H2("Was benötigt wird"), bullet("Windows mit installiertem Python 3."), bullet("Ein gültiger OAuth-Token in <b>data\\token.json</b>."), bullet("Das Google-Konto muss beim Zielkanal ausreichende YouTube-Moderationsrechte besitzen."), bullet("Eine Internetverbindung und aktivierte YouTube Data API."),
          H2("Wichtige Startdateien"), data_table(["Datei","Aufgabe"],[
              ("CHATWAECHTER_EXAKT_40_STARTEN.vbs","Normaler, leiser Start des Control Centers."),
              ("CHATWAECHTER_CONTROL_CENTER_DIAGNOSE.cmd","Diagnose bei Start-, Python- oder Verbindungsproblemen."),
              ("AUTO_LIVE_CHATWAECHTER.py","Hintergrundwächter; wird normalerweise automatisch gestartet."),
              ("YOUTUBE_TOKEN_ERSTELLEN.cmd","Erstellt den OAuth-Token erneut, falls die Anmeldung ungültig ist."),
              ("BEDIENUNGSANLEITUNG_PDF_AKTUALISIEREN.cmd","Erzeugt diese komplette PDF neu und überschreibt die alte Ausgabe."),
          ], [58*mm,116*mm]),
          H2("Was beim Start automatisch geschieht"), P("Das Control Center prüft Python, Token, Datenordner und Wächterprozess. Falls kein Wächter läuft, wird er unsichtbar gestartet. Regeln werden in den lokalen Datenordner kopiert und die Statusdatei wird regelmäßig eingelesen.")]

    s += [H1("3 · Das Dashboard")]
    if DASHBOARD_IMAGE.exists():
        img = Image(str(DASHBOARD_IMAGE), width=174*mm, height=93.3*mm)
        s += [img, P("Abbildung: Dashboard im Zustand BEREIT – verbunden, aber ohne aktiven Livestream.", "Small")]
    s += [H2("Kopfbereich"), data_table(["Element","Bedeutung"],[
        ("Stream Status","BEREIT, ONLINE oder OFFLINE."),("Verbindung","Verbunden oder Getrennt."),("Livestream-Titel","Name des erkannten Streams; im Wartemodus „Warte auf Livestream“."),("Livestream öffnen","Öffnet das erkannte Video zusätzlich im Standardbrowser."),
    ], [48*mm,126*mm]),
    H2("Kennzahlen und Diagramme"), bullet("<b>Nachrichten:</b> Anzahl der eingelesenen Chatnachrichten."), bullet("<b>Regel-Treffer:</b> Nachrichten, die mindestens eine Regel ausgelöst haben."), bullet("<b>Aktive Zuschauer:</b> Die Chat-API liefert keine verlässliche vollständige Zuschauerzahl; daher kann hier ein Hinweis stehen."), bullet("<b>Status – Schutz aktiv:</b> Regeln und Überwachung sind eingeschaltet."), bullet("<b>Löschungsquote:</b> Verhältnis tatsächlich gelöschter zu allen protokollierten Nachrichten."), bullet("Verlaufsdiagramme und Regelbalken zeigen Häufigkeiten des aktuellen Chats."),
    H2("Nachrichtenbereich"), P("Die Schalter <b>Alle</b>, <b>Nur Treffer</b> und <b>Gelöscht</b> filtern die Tabelle. Die Reiter darunter zeigen alle Nachrichten, nur Treffer, gelöschte Nachrichten oder vorherige Chats. Das Suchfeld filtert Text, Nutzer und Regelangaben.")]

    s += [H1("4 · Livestream-Suche, Video und Livechat")]
    s += [H2("Automatische Suche"), P("Im Zustand BEREIT fragt der Wächter den eingestellten Kanal regelmäßig nach einem aktiven Livestream ab. Der Fortschrittskreis unten rechts füllt sich über 45 Sekunden. Danach wird erneut gesucht und der Kreis beginnt wieder leer."),
          H2("Manuelle Suche"), P("Mit <b>Jetzt suchen</b> wird eine zusätzliche echte YouTube-Abfrage ausgelöst. Der Knopf zeigt währenddessen „Suche …“ und ist vorübergehend gesperrt. Das ersetzt die automatische Suche nicht."),
          H2("Video"), P("Ein erkanntes Video wird im 16:9-Bereich eingebettet. Ohne aktiven Stream bleibt die Wartedarstellung sichtbar. Falls die Einbettung nicht lädt, kann <b>Livestream öffnen</b> verwendet werden."),
          H2("Offizieller YouTube-Livechat"), P("Rechts wird bei aktivem Stream der offizielle YouTube-Livechat geladen. Dadurch stehen Schreiben, Standard-Emojis und alle für das angemeldete Konto verfügbaren Kanal-/Mitglieder-Emojis zur Verfügung."),
          box("<b>Zwei Anmeldungen:</b> Der OAuth-Token erlaubt dem Wächter API-Aktionen. Die Anmeldung innerhalb des eingebetteten Chats ist eine separate Browseranmeldung und kann beim ersten Mal erneut verlangt werden.", YELLOW, colors.HexColor("#FFF7DE")),
          H2("Wenn kein Stream gefunden wird"), bullet("Prüfen, ob der Stream wirklich öffentlich und bereits live ist."), bullet("Prüfen, ob er zum konfigurierten Kanal gehört."), bullet("Jetzt suchen anklicken und einige Sekunden warten."), bullet("Unter Kanal & Einstellungen den API-Test ausführen.")]

    s += [H1("5 · Menüpunkt LIVE MONITORING")]
    s += [P("Dieses Fenster zeigt die Rohdaten des aktuell erkannten Streams: interner Status, Titel, Video-ID, URL und bisherige Nachrichtenanzahl."),
          data_table(["Feld","Verwendung"],[("Status","waiting = wartet; connected = Stream aktiv; starting = Wächter startet."),("Titel","Von YouTube gelieferter Streamtitel."),("Video-ID","Eindeutige YouTube-Kennung des Streams."),("URL","Direkter Link zum Video."),("Nachrichten","Bisher protokollierte Nachrichten im laufenden Chat.")],[42*mm,132*mm]),
          P("Der Knopf <b>Livestream öffnen</b> ist nur aktiv, wenn eine URL vorhanden ist.")]

    s += [H1("6 · Menüpunkt NACHRICHTEN")]
    s += [P("Zeigt bis zu 1.000 der zuletzt geladenen Nachrichten des aktuellen Chats in einer größeren Tabelle."),
          data_table(["Spalte","Inhalt"],[("Zeit","Veröffentlichungs- oder Empfangszeit."),("Nutzer","Anzeigename des YouTube-Kontos."),("Rolle","Kanalinhaber, Moderator, Mitglied oder Zuschauer."),("Nachricht","Originaltext der Chatnachricht."),("Aktion","Markierung, Löschung, Stummschaltung oder Sperre."),("Begründung","Ausgelöste Regel bzw. API-Fehler.")],[38*mm,136*mm]),
          H2("Farbige Emoji-Darstellung"), P("Nachrichten, die nur aus Emojis bestehen, werden zur besseren Lesbarkeit farblich hervorgehoben: Herzen rot/rosa, lachende und winkende Emojis gelb, traurige Emojis blau und übrige Emojis cyan. Normaler Nachrichtentext bleibt weiß. Die Einfärbung gilt für Dashboard, Nachrichtenfenster und Protokollansicht."),
          box("Die Nachrichtenansicht zeigt Daten; sie löst selbst keine zusätzliche Moderationsaktion aus.")]

    s += [H1("7 · Regeln richtig bedienen")]
    s += [H2("Grundregel"), P("Jede Regel wird separat eingestellt und gespeichert. In der erweiterten Übersicht besitzt jede Zeile ein eigenes Kontrollkästchen <b>Aktiv</b>. Häkchen = eingeschaltet, leeres Feld = ausgeschaltet."),
          H2("Regelbereiche"), data_table(["Bereich","Was wird eingestellt"],[
              ("Beleidigungen bearbeiten","Begriffsliste und Aktion bei einem Treffer."),("Emoji-Regel bearbeiten","Maximale Emoji-Anzahl und Aktion."),("Großschreibung bearbeiten","Mindestzahl Buchstaben, Verhältnis Großbuchstaben und Aktion."),("Erweiterte Regeln anzeigen","Alle spezialisierten Regeln zeilenweise aktivieren/deaktivieren."),("Regel hinzufügen","Eigene Begriffe/Muster mit eigener Aktion anlegen."),
          ], [55*mm,119*mm]),
          H2("Mögliche Aktionen"), data_table(["Aktion","Auswirkung"],[
              ("Nur markieren","Nur lokaler Treffer; auf YouTube wird nichts verändert."),("Nachricht löschen","Entfernt die Nachricht über die YouTube-API."),("Stumm 5/10/30 Minuten","Temporäre Chatsperre für die gewählte Dauer."),("Stumm 1/24 Stunden","Längere temporäre Chatsperre."),("Nutzer dauerhaft blockieren","Permanente Chatsperre, die unter SPERREN aufgehoben werden kann."),
          ], [58*mm,116*mm]),
          box("Neue oder unsichere Regeln zuerst nur auf <b>Nur markieren</b> stellen. Nach dem Stream im Protokoll auf Fehlalarme prüfen.", YELLOW, colors.HexColor("#FFF7DE"))]

    s += [H1("8 · Alle erweiterten Regeln")]
    advanced = [
        ("Wiederholte Nachrichten","Mehrere identische Nachrichten desselben Nutzers im Zeitfenster."),("Flood","Sehr viele Nachrichten eines Nutzers in kurzer Zeit."),("Gleiche Zeichen","Lange Folgen wie !!!!!, hahahaha oder looooool."),("Mehrere Links","Mehrere Weblinks in einer Nachricht."),("Werbesätze","Eigenwerbung wie „abonniert meinen Kanal“ oder „Link im Profil“."),("Kontaktdaten","Telefonnummern, E-Mail, Discord-, Telegram- oder WhatsApp-Angaben."),("Betrugsbegriffe","Gewinnspiel-, Krypto-, Investitions- oder falsche Support-Angebote."),("Viele Erwähnungen","Ungewöhnlich viele @Nutzer-Angaben."),("Sehr lange Nachricht","Nachricht oberhalb der eingestellten Zeichenzahl."),("Mehrzeiliger Spam","ASCII-Art oder zu viele Zeilen."),("Fast gleiche Kopien","Texte, bei denen nur einzelne Zeichen/Emojis geändert wurden."),("Private Daten","Mögliche personenbezogene Daten; sollte mindestens gelöscht werden."),("Drohungen","Eindeutige Gewaltandrohungen."),("Hassrede","Angriffe gegen Personengruppen; standardmäßig vorsichtig konfigurieren."),("Sexuelle Inhalte","Explizite Begriffe/Aufforderungen."),("Spoiler","Zeitweise gesperrte Namen oder Begriffe."),("Themenfilter","Politische, religiöse oder andere streamabhängige Themen."),("Fremdsprache","Nur sinnvoll bei ausdrücklich einsprachigem Chat; zunächst markieren."),("Wiederholungstäter","Eskalation über mehrere Verstöße mit Verfallszeit."),
    ]
    s += [data_table(["Regel","Erklärung"], advanced, [55*mm,119*mm]),
          H2("Normalisierung gegen Umgehungen"), P("Die Beleidigungsregel enthält 100 allgemeine deutsche Filterbegriffe. Die direkte Prüfung verwendet Wortgrenzen, damit kurze Begriffe nicht versehentlich innerhalb harmloser Wörter auslösen. Zusätzlich vereinheitlicht der Wächter Schreibvarianten: Leerzeichen, Punkte und andere Trennzeichen werden entfernt; typische Zahlentausche werden zurückübersetzt. Dadurch werden beispielsweise <b>i d i o t</b>, <b>i.d.i.o.t</b>, <b>1 d 1 o t</b> oder <b>a r s c h l o c h</b> als umgangene Beleidigung erkannt. Die berechnete Aktion ist Löschen."),
          H2("Ausnahmen und Vertrauen"), bullet("Kanalinhaber und Moderatoren können von leichten Regeln ausgenommen werden."), bullet("Vertrauenslisten können bekannte Stammzuschauer bei leichten Spamregeln schonen."), bullet("Schwere Regeln sollten nicht blind von Ausnahmen befreit werden.")]

    s += [H1("9 · Automatische Moderation und Eskalation")]
    s += [box("<b>Aktuelle Grundeinstellung:</b> Nur Großschreibung und Beleidigungen sind aktiviert. Beide Regeln löschen die betreffende Nachricht. Alle anderen Erkennungsregeln sind deaktiviert.", GREEN, colors.HexColor("#EAF8F1")),
    data_table(["Typischer Verstoß","Vorgeschlagene Reaktion"],[
        ("Beleidigung","Löschen oder 10 Minuten stumm."),("Spam / Werbung","30 Minuten stumm."),("Wiederholung","Zunächst markieren."),("Flood","5 Minuten stumm."),("Schwere eindeutige eigene Regel","Dauerhaft blockieren; Rücknahme ermöglichen."),
    ], [62*mm,112*mm]),
    H2("Wiederholungstäter"), P("Eine mögliche Eskalation lautet: erster Verstoß markieren, zweiter Verstoß 5 Minuten stumm, dritter Verstoß 30 Minuten stumm, weiterer schwerer Verstoß dauerhaft blockieren. Punkte bzw. Verstöße können nach der eingestellten Verfallszeit wieder verschwinden."),
    H2("Was im Protokoll gespeichert wird"), P("Originalnachricht, Nutzer, Rolle, Trefferregeln, angeforderte Aktion, Ergebnis der YouTube-API und mögliche Fehlermeldung. Eine angeforderte Aktion gilt erst dann als erfolgreich, wenn die API dies bestätigt.")]

    s += [H1("10 · MODERATOREN und SPERREN")]
    s += [H2("Moderatoren"), P("Die Ansicht listet Kanalinhaber und Moderatoren auf, die im aktuell geladenen Chat tatsächlich erkannt wurden. Angezeigt werden Name, Rolle und Kanal-ID. Wer noch keine Nachricht geschrieben hat, kann dort fehlen."),
          H2("Dauerhafte Sperren"), P("Unter SPERREN erscheinen permanente Blockierungen des aktuell geladenen Chats, sofern die notwendige YouTube-Sperr-ID protokolliert wurde."),
          step(1,"Eintrag auswählen","Nutzername, Uhrzeit und damalige Nachricht kontrollieren."), step(2,"Sperre aufheben","Ausgewählte Sperre aufheben anklicken."), step(3,"API-Ergebnis abwarten","Erst die Erfolgsmeldung bestätigt die Rücknahme auf YouTube."),
          box("Temporäre Stummschaltungen laufen automatisch ab. Eine permanente Sperre muss ausdrücklich aufgehoben werden.", RED, colors.HexColor("#FFF0F2"))]

    s += [H1("11 · PROTOKOLL, Archiv und Export")]
    s += [H2("Protokollübersicht"), P("Die Übersicht durchsucht <b>data\\logs</b> nach gespeicherten Streams und zeigt Datum, Video-ID, Nachrichten, Treffer und Löschungen. Nach Auswahl kann der Chat geöffnet werden."),
          H2("Filter"), bullet("Normaler Chat / Alle: sämtliche gespeicherten Nachrichten."), bullet("Nur Treffer: Nachrichten aus der Trefferdatei."), bullet("Nur Löschungen: Zeilen mit bestätigter Löschung."),
          H2("Exportformate"), data_table(["Format","Geeignet für"],[("CSV","Excel und schnelle Auswertung."),("JSON","Vollständige technische Weiterverarbeitung."),("PDF","Lesbare Weitergabe oder Archivierung."),("PNG","Bild der aktuellen Dashboardansicht.")],[42*mm,132*mm]),
          H2("Importierte Chatwiedergaben"), P("Vorhanden sind 9.444 Nachrichten vom 12.07.2026 (Video 5tDmJxoT9OQ) und 10.834 Nachrichten vom 06.07.2026 (Video 21PShDk3u-Y). Standard-Emojis werden als echte Unicode-Zeichen dargestellt. YouTube-Spezialemojis werden, soweit möglich, durch ein passendes sichtbares Emoji ersetzt; andernfalls erscheint ein lesbarer Name. Bei Wiedergaben können frühere Löschungen, Sperren und damalige Regeltreffer nicht zuverlässig rekonstruiert werden."),
          box("Ein Stream wird nur automatisch vollständig protokolliert, wenn der Wächter während des Livebetriebs läuft. Nachträglicher Import ist nur möglich, solange YouTube eine Chatwiedergabe bereitstellt.", YELLOW, colors.HexColor("#FFF7DE"))]

    s += [H1("12 · STATISTIKEN und ALARME")]
    s += [H2("Statistiken"), P("Zeigt für den aktuell geladenen Livestream: Nachrichtenanzahl, Regel-Treffer, bestätigte Löschungen und Trefferquote in Prozent."),
          H2("Alarme"), P("Listet fehlgeschlagene Löschungen und fehlgeschlagene Sperren mit dem von YouTube gelieferten Fehlertext. „Keine aktuellen Alarme“ bedeutet, dass im geladenen Datensatz keine fehlgeschlagene Moderationsaktion erkannt wurde."),
          H2("Häufige Alarmursachen"), bullet("Der angemeldete Account besitzt nicht genügend Rechte."), bullet("Nachricht oder Nutzerstatus wurde zwischenzeitlich geändert."), bullet("Token ist abgelaufen oder wurde widerrufen."), bullet("YouTube-API-Kontingent oder Verbindung ist vorübergehend gestört.")]

    s += [H1("13 · KANAL & EINSTELLUNGEN")]
    s += [P("Zeigt den überwachten Kanal sowie die lokalen Pfade zu Token, Status, Logs und Regeln."),
          H2("API testen"), P("Startet bzw. prüft den Hintergrundwächter und liest anschließend die Statusdatei. Mögliche Erfolgsmeldungen: „API verbunden – Livestream aktiv“, „API verbunden – warte auf Livestream“ oder „API-Anmeldung erfolgreich – Wächter startet“."),
          H2("Logordner öffnen"), P("Öffnet <b>data\\logs</b> im Windows-Explorer."),
          H2("Kanalwechsel"), P("Der Wächter verwendet den bei der Google-Anmeldung ausgewählten YouTube-Kanal. Ein Kanalwechsel erfordert eine erneute Anmeldung mit dem gewünschten Konto."),
          box("<b>API testen</b> sendet keine Testnachricht und führt keine Moderationsaktion aus. Es prüft Anmeldung, Wächter und Status.")]

    s += [H1("14 · SYSTEM und Neustart")]
    s += [P("Die Systemansicht zeigt Betriebssystem, gefundenen Python-Pfad, Wächterzustand und Statusdatei."),
          H2("Wächter neu starten"), P("Beendet den aktuell registrierten Python-Prozess, entfernt die alte PID-Datei und startet den Wächter neu. Eine Erfolgsmeldung zeigt neue Prozess-ID und Startzeit."),
          H2("Wann neu starten?"), bullet("Nach Änderungen an AUTO_LIVE_CHATWAECHTER.py."), bullet("Wenn OFFLINE / GETRENNT dauerhaft angezeigt wird."), bullet("Wenn der Statuszeitpunkt nicht mehr aktualisiert wird."), bullet("Nach einer Token-Erneuerung."),
          box("Regeländerungen werden normalerweise ohne Wächterneustart neu geladen. Änderungen am Python-Programm benötigen dagegen einen Neustart.", GREEN, colors.HexColor("#EAF8F1"))]

    s += [H1("15 · WERKZEUGE & SICHERHEIT – die 15 Erweiterungen")]
    s += [P("Der neue Menüpunkt <b>WERKZEUGE</b> bündelt Sicherheitssteuerung, Simulation, Prüfliste, Nutzerakten, Profile, Zeitsteuerung, Sicherungen, Berichte und Gesundheitsdaten."),
          H2("1. Testmodus mit alten Chats"), P("Im Reiter Simulation auf <b>Alten Chat testen</b> klicken und eine Datei mit der Endung -all_messages.jsonl auswählen. Während der Prüfung erscheint ein Wartehinweis. Danach wird der geprüfte Chat als übersichtliche, dunkel gestaltete Tabelle mit den Spalten <b>Datum, Uhrzeit, Name, Nachricht, Status, Regel und Aktion</b> dargestellt. Die Spalte Regel verwendet verständliche deutsche Namen wie „Zu viele gleiche Zeichen“ oder „Spamwelle“. Ist ein langer Inhalt abgeschnitten, zeigt das Verweilen mit der Maus den vollständigen Text. Treffer sind deutlich dunkelrot hervorgehoben; Nachrichten ohne Verstoß tragen den Status OK. Oberhalb der Tabelle steht die Gesamtzahl. Es werden keine echten YouTube-Aktionen ausgeführt."),
          H2("2. Not-Aus"), P("Der Not-Aus ist als eigene, jederzeit sichtbare Dashboard-Kachel vorhanden und zusätzlich unter WERKZEUGE → Sicherheit erreichbar. Der große rote Kreis mit <b>STOP</b> ist die Schaltfläche: Ein Klick hält alle automatischen und manuellen YouTube-Moderationsaktionen an. Überwachung, Regelerkennung und Protokollierung laufen weiter. Bei aktivem Not-Aus zeigt der Kreis ein großes <b>!</b>, pulsiert in zwei Rottönen und die Kachel meldet deutlich „NOT-AUS AKTIV“. Ein erneuter Klick auf den Kreis schaltet die Automatik wieder ein."),
          H2("3. Treffer-Prüfliste"), P("Der Reiter Prüfliste zeigt die letzten markierten Nachrichten. Über Rechtsklick kann eine echte Aktion gewählt, eine Nutzerakte geöffnet oder der Nutzer auf die Vertrauensliste gesetzt werden. <b>Auswahl als geprüft entfernen</b> entfernt einen Eintrag nur aus der aktuellen Prüfansicht."),
          H2("4. Nutzerakte"), P("Zeigt für einen Nutzer Nachrichtenanzahl, Treffer, Löschungen, Sperren und den bisherigen Nachrichtenverlauf des geladenen Chats. Öffnen über den Reiter Nutzer & Notizen oder per Rechtsklick auf eine Chatzeile."),
          H2("5. Manuelle Aktionen per Rechtsklick"), P("Im Dashboard-Chat, Livechat-Ersatzraster und in der Prüfliste stehen Löschen, 5/10/30 Minuten, 1/24 Stunden stumm sowie dauerhaft blockieren zur Verfügung. Diese Befehle funktionieren nur bei aktivem Livestream und deaktiviertem Not-Aus."),
          H2("6. Regelprofile"), data_table(["Profil","Wirkung"],[("Normal","Behält die normale Regelkonfiguration."),("Familienfreundlich","Strengere Emoji-, Großschreibungs-, Privatdaten- und Inhaltsregeln."),("Streng","Niedrigere Spam-/Flood-Schwellen und stärkere Aktionen."),("Nur markieren","Setzt vorhandene Regelaktionen auf Markieren; ideal zum Testen."),("Spamwelle","Verschärft Wiederholung, Flood und weitere gehäufte Regeltreffer.")],[50*mm,124*mm]),
          H2("7. Regel-Simulator"), P("Die deutlich mit <b>NACHRICHT PRÜFEN</b> beschriftete Einzelprüfung befindet sich direkt unter dem YouTube-Livechat oben rechts. Eine Nachricht in einer nativen Chatliste doppelt anklicken: Der Text wird automatisch in das Prüffeld übernommen. Alternativ kann Text eingetippt werden. Danach <b>Text prüfen</b> anklicken. Darunter erscheinen Trefferregel und berechnete Aktion oder „Kein Treffer“. Die Prüfung führt niemals eine echte YouTube-Aktion aus. Unter WERKZEUGE → Simulation bleibt ausschließlich die vollständige Prüfung alter Chats."),
          H2("8. Automatischer Spamwellenmodus"), P("Der Wächter zählt Treffer in einem kurzen Zeitfenster. Wird die konfigurierte Grenze erreicht, wird die Regel Spamwelle aktiv und führt die eingestellte stärkere Aktion aus. Unter Sicherheit wird der aktuelle Zustand angezeigt."),
          H2("9. Rückgängig-Zentrale"), P("Öffnet die Verwaltung dauerhafter Sperren. Eine Sperre kann aufgehoben werden, wenn die YouTube-Sperr-ID im aktuellen Protokoll vorhanden ist."),
          H2("10. API-Zähler"), P("Unter Sicherheit wird die Anzahl der vom Wächter seit seinem Start gezählten YouTube-API-Aufrufe angezeigt. Dies ist eine Betriebsanzeige, keine garantierte exakte Google-Quota-Abrechnung."),
          H2("11. Gesundheitsüberwachung"), P("Zeigt Wächterstatus und Alter des letzten Herzschlags. Ein dauerhaft steigender Wert ohne neue Statusdatei weist auf einen festhängenden oder beendeten Prozess hin."),
          H2("12. Automatische Sicherungen"), P("Beim ersten Control-Center-Start eines Tages wird automatisch eine ZIP-Sicherung von Regeln, Logs, Berichten, Zeitplan und Nutzernotizen erzeugt. <b>Jetzt sichern</b> startet zusätzlich eine manuelle Sicherung. Maximal 30 automatische Sicherungsstände werden behalten."),
          H2("13. Stream-Abschlussbericht"), P("Beim erkannten Streamende schreibt der Wächter unter data\\reports einen JSON- und PDF-Bericht mit Nachrichten, Regeltreffern, Löschungen, Sperren, häufigsten Regeln und aktivsten Nutzern."),
          H2("14. Zeitgesteuerte Profile"), P("Profil auswählen, Start- und Endzeit im Format HH:MM eintragen und <b>Zeitprofil speichern</b> anklicken. Das Profil wird täglich in diesem Zeitraum zusätzlich angewendet; Zeiträume über Mitternacht werden unterstützt."),
          H2("15. Moderatornotizen"), P("In der Nutzerakte können interne Notizen gespeichert werden. Sie liegen lokal in data\\user_notes.json, werden nicht an YouTube gesendet und sind Bestandteil der Sicherung."),
          box("Profile und Zeitpläne verändern die Regelwirkung. Vor dem Einsatz eines strengen Profils zuerst den Simulator oder einen alten Chat verwenden.", YELLOW, colors.HexColor("#FFF7DE"))]

    s += [H1("16 · Fehlerhilfe nach Symptom")]
    problems = [
        ("BEREIT, aber kein Video","Normal ohne aktiven Stream. Jetzt suchen, Kanal und Öffentlichkeit des Streams prüfen."),("OFFLINE / GETRENNT","SYSTEM öffnen, Wächter neu starten, danach Diagnose und watcher_stderr.txt prüfen."),("Python nicht gefunden","Python 3 installieren bzw. vorhandenen Pfad prüfen. Aktuell wird unter anderem Miniconda unterstützt."),("Token fehlt/ungültig","YOUTUBE_TOKEN_ERSTELLEN.cmd ausführen und das Moderatorkonto auswählen."),("API testen scheint wirkungslos","Ergebnisfenster abwarten; Statusdatei und Fehlerlogs prüfen."),("Chat zeigt keine Eingabe","Nur bei aktivem Stream möglich; im eingebetteten YouTube-Chat anmelden."),("Emoji fehlt","Emoji muss für das im Chat angemeldete Konto verfügbar sein. Mitgliederemojis benötigen ggf. Mitgliedschaft."),("Neue Regel nicht sichtbar","Regelfenster schließen/neu öffnen und darauf achten, separat zu speichern."),("Regel reagiert nicht","Aktiv-Häkchen, Grenzwert, Begriffsliste, Ausnahmen und data\\rules.json prüfen."),("Zu viele Fehlalarme","Aktion auf Nur markieren setzen, Schwelle erhöhen, Begriffe präzisieren."),("Protokoll fehlt","data\\logs prüfen. Der Wächter muss während des Streams gelaufen sein."),("Sperre nicht rückgängig machbar","Es muss eine gespeicherte permanente banId vorhanden sein und das Konto braucht Rechte."),("Dashboard startet nicht","CHATWAECHTER_STARTFEHLER.txt und CHATWAECHTER_NAVIGATIONSFEHLER.txt lesen."),("Aktualisierung stoppt","CHATWAECHTER_TIMERFEHLER.txt prüfen und Control Center neu starten."),
    ]
    s += [data_table(["Problem","Lösung"], problems, [58*mm,116*mm]),
          H2("Diagnosedateien"), data_table(["Datei","Inhalt"],[("CHATWAECHTER_STARTFEHLER.txt","Fehler beim Start der Oberfläche."),("CHATWAECHTER_NAVIGATIONSFEHLER.txt","Fehler beim Öffnen eines Menüpunkts."),("CHATWAECHTER_TIMERFEHLER.txt","Fehler bei der automatischen Aktualisierung."),("data\\watcher_stderr.txt","Python- und API-Fehler des Wächters."),("data\\watcher_stdout.txt","Normale Ausgaben des Wächters.")],[62*mm,112*mm])]

    s += [H1("17 · Sicherheit, Rechte und Grenzen")]
    s += [H2("Token schützen"), P("<b>data\\token.json</b> ist eine Zugangsinformation. Nicht verschicken, nicht öffentlich hochladen und nicht in Screenshots zeigen. Bei Verdacht den Zugriff im Google-Konto widerrufen und einen neuen Token erstellen."),
          H2("Moderator statt Kanalinhaber"), P("Der Wächter kann nur Aktionen ausführen, die YouTube dem angemeldeten Moderator erlaubt. Kanalinhaber-Funktionen werden dadurch nicht automatisch verfügbar."),
          H2("API- und Plattformgrenzen"), bullet("Keine verlässliche vollständige Zuschauerzahl über die Chat-API."), bullet("YouTube kann Aktionen ablehnen oder verzögern."), bullet("Chatwiedergaben enthalten nicht zuverlässig alle früheren Moderationsereignisse."), bullet("Exklusive Emojis stehen nur Konten mit entsprechender Berechtigung zur Verfügung."),
          H2("Datenschutz"), P("Protokolle enthalten Nutzernamen, Kanal-IDs, Nachrichten und Zeitpunkte. Sie sollten nur für Moderation und berechtigte Dokumentation verwendet, geschützt gespeichert und nicht unnötig weitergegeben werden.")]

    s += [H1("18 · Datensicherung und vollständige Neuerstellung dieser Anleitung")]
    s += [H2("Was sichern?"), bullet("data\\logs – Chatprotokolle."), bullet("data\\rules.json und rules.json – Regelkonfiguration."), bullet("CHATWAECHTER_BEDIENUNGSANLEITUNG.pdf – aktuelle Dokumentation."), bullet("Token nur in einer verschlüsselten privaten Sicherung."),
          H2("Anleitung neu erzeugen"), P("Doppelklicke auf <b>BEDIENUNGSANLEITUNG_PDF_AKTUALISIEREN.cmd</b>. Der Generator baut die komplette Anleitung von der Titelseite bis zum letzten Kapitel neu und überschreibt die vorhandene PDF. Es werden keine Ergänzungsseiten an eine alte Ausgabe angehängt."),
          box("Bei jeder künftigen Funktionsänderung wird der Inhalt dieser Hauptausgabe angepasst und danach die gesamte PDF neu erstellt.", GREEN, colors.HexColor("#EAF8F1")),
          H2("Versionsstand"), data_table(["Version","Datum","Umfang"],[(VERSION, VERSION_DATE,"Vollständige Neuausgabe einschließlich reparierter Simulation alter Chats mit Inhaber- und Moderatornachrichten, großem rotem Not-Aus-Kreis, vollständig lesbarer Statusanzeige, Prüfliste, Nutzerakte, Rechtsklickmoderation, Profilen, Spamwellenmodus, Rückgängig-Zentrale, API-/Gesundheitsanzeige, Sicherungen, Abschlussberichten, Zeitprofilen und Notizen.")],[28*mm,30*mm,116*mm])]

    s += [H1("19 · Glossar")]
    glossary = [("API","Schnittstelle, über die der Wächter mit YouTube kommuniziert."),("OAuth-Token","Gespeicherte Berechtigung des angemeldeten Google-Kontos."),("Video-ID","Eindeutige Zeichenfolge eines YouTube-Videos."),("LiveChat-ID","Interne Kennung des zu einem aktiven Stream gehörenden Chats."),("JSONL","Protokollformat: eine vollständige JSON-Nachricht pro Zeile."),("Regeltreffer","Eine Nachricht erfüllt mindestens eine aktivierte Erkennung."),("Timeout / Stumm","Zeitlich begrenzte Chatsperre."),("Blockierung","Dauerhafte Chatsperre bis zur Rücknahme."),("PID","Prozessnummer des laufenden Python-Wächters."),("Chatwiedergabe","Von YouTube bereitgestellter nachträglicher Verlauf eines Livestream-Chats.")]
    s += [data_table(["Begriff","Erklärung"], glossary, [45*mm,129*mm]), Spacer(1,8*mm), P("Ende der vollständigen Bedienungsanleitung.", "Small")]
    return s


def main():
    doc = ManualDocument(str(TARGET), pagesize=A4, leftMargin=16*mm, rightMargin=16*mm, topMargin=17*mm, bottomMargin=17*mm, title="Chatwächter Bedienungsanleitung", author="Chatwächter Control Center 2026")
    doc.multiBuild(build_story())
    print(f"Vollständige PDF neu erstellt: {TARGET}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
