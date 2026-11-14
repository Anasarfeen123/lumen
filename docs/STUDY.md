# Study

Lumen's study companion: your `~/Academics` folder, past papers, VTOP's lecture plans and
syllabi, and your progress — in the AmazeCC app's **Study** section (Ctrl+Super+A), the
launcher and Halo. It needs AmazeCC set up (Settings → AmazeCC); `scripts/study.py` does
the work and `shell/services/Study.qml` runs it in the background.

## Where things come from

| What | Source | Saved to |
|---|---|---|
| Past papers (PYQs) | four collections: **MIC PYQs** (`pyq.microsoftinnovationsclub.in`, which carries vhelp's papers), **ExamCooker** (ACM-VIT, its public course pages), and the GitHub repos **Nirant07/VIT-Papers** and **puneet-chandna/VIT-PYQPs-Paaji** — matched to your courses by code, title or the short name a collection uses (DBMS, TOC, OS, Java); the same paper from two collections (identical file) is kept once, and nothing you already have in your own folders is fetched again | `<course>/Exams & Question Papers/PYQs/CAT 1 2025 Slot B2.pdf` |
| Lecture plans | VTOP's course page for *your* slot and teacher, through your AmazeCC API | `~/.local/state/lumen/study/lectures.json` |
| Syllabi | VTOP's curriculum page (a course with theory and lab gets both) | `<course>/Syllabus/<code> Syllabus ETH (VTOP).pdf` |
| Missed classes | AmazeCC's daily attendance history (a class where the total went up but you didn't) | — |
| Events, buses | your AmazeCC API's public pages | — |
| Search index | your notes and PDFs; scanned question papers are read with OCR (tesseract) | `~/.cache/lumen/study/` |
| Progress | papers done, modules revised, flashcard reviews, study sessions | `~/.local/state/lumen/study/progress.json` |

The collections are checked at most once every 20 hours, only for your courses, one
request a second, at most 120 downloads a run (the rest come the next day); a paper you
delete isn't fetched again. Postgraduate (MCA) versions of a course are skipped. vhelp
itself (`vhelpcc.com/pyqs`) is a page drawn by JavaScript with no links to read; its papers
arrive through the MIC collection.
Course folders are found by the code at the start of the folder's name
(`BACSE202 - Database Systems (DBMS)`), else by its title, in the semester folder marked
`(Current)`. Unity projects (folders with `Assets` and `ProjectSettings`) are never indexed.

## In the background

- **Daily:** new past papers → a Halo card ("3 new past papers · Database Systems").
- **Every 3 days:** lecture plans and syllabi from VTOP.
- **Every 6 hours:** the search index (only what changed).
- **Before an exam (6 days out):** once a day, "FAT in 4 days — 8 past FAT papers, 2 done",
  with Past papers and Revise 45 min.
- **Mornings (first unlock, 6–12):** exams this week, a paper to practise, labs today.
- **Downloads:** a course file lands in `~/Downloads` → "File into Database Systems?
  → Assignments & Labs" (it uses the subfolders each course really has).
- **Backup:** if the 23:00 vault backup didn't run or logged an error, Halo says so.

## The app's Study pages

**Study** (upcoming exams with seat and papers done; each course: papers, lectures covered,
minutes studied this week, attendance and how many classes you can still miss, what you need
in the FAT for S/A/B/C on VIT's absolute scale; missed classes and their topics; recent files;
the backup; making the next semester's folders) · **Past papers** (filter by course and exam,
tick what you've practised, count which lecture topics come up most, ask Halo about a paper)
· **Lectures** (the plan, what's covered, what you missed; syllabus PDFs; a module checklist)
· **Flashcards** (from `**Term:** meaning` lines and headed sections in your cheat sheets,
plus a `flashcards.json` of `[{q, a}]`; Again / Hard / Good / Easy) · **Find notes** ·
**Events & buses**.

## Launcher and Halo

- Launcher: `s deadlock` (your notes), `pyq dbms` (that course's papers), `revise os 30`,
  and the entries Study, Past papers, Lecture plan, Flashcards, Find in my notes.
- Halo: "past papers for dbms", "what did I miss in OS", "study moc for 30 minutes",
  "what comes up in the dbms fat", "find deadlock in my notes", "quiz me on java".
  (Course names: code, title, initials, or the abbreviation in your folder name.)

## Not available

- Faculty course **materials** can be listed on VTOP but your AmazeCC API has no route to
  download the files; the question bank (`/api/qbank`) needs the API's database; the class
  average (`marks/stats`) needs AmazeCC's class sharing; the teacher search returns nothing.
- Java, AR/VR and Soft Skills have no papers in the MIC collection yet (checked daily).
- AR/VR's and Models of Computation's teachers haven't published lecture plans on VTOP.
