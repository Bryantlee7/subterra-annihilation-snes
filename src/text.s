; ---------------------------------------------------------------- mission text
; Briefings: up to 27 columns per line, 11 lines.

mis_names: .addr mn1, mn2, mn3, mn4, mn5, mn6, mn7, mn8, mn9, mn10
mn1:  .byte "STREET LEVEL", 0
mn2:  .byte "THE NEST", 0
mn3:  .byte "DEEP DIG", 0
mn4:  .byte "POWER GRID", 0
mn5:  .byte "THE SENTINEL", 0
mn6:  .byte "BLACKOUT", 0
mn7:  .byte "PRISONERS", 0
mn8:  .byte "COLLAPSE", 0
mn9:  .byte "COMMAND POST", 0
mn10: .byte "THE FACILITY", 0

mis_music: .word MUS_CITY, MUS_CAVE, MUS_CAVE, MUS_TECH, MUS_BOSS, MUS_TECH, MUS_CAVE, MUS_CHASE, MUS_TECH, MUS_TECH

mis_brief: .addr mb1, mb2, mb3, mb4, mb5, mb6, mb7, mb8, mb9, mb10
mb1:
    .byte "YOUR FRIEND HAS BEEN TAKEN", 10
    .byte "TO A SECRET FACILITY DEEP", 10
    .byte "BENEATH THE CITY.", 10, 10
    .byte "SUIT UP. CROSS THE STREETS,", 10
    .byte "FIND THE MAINTENANCE SHAFT", 10
    .byte "AND REACH THE EXIT LIFT IN", 10
    .byte "THE TUNNELS BELOW.", 0
mb2:
    .byte "THE TUNNELS BRANCH LIKE AN", 10
    .byte "ANT COLONY. THE LIFT DOWN", 10
    .byte "IS SEALED.", 10, 10
    .byte "RECOVER 3 DATA CHIPS TO", 10
    .byte "UNLOCK IT. CHECK THE DEAD", 10
    .byte "ENDS. PRESS SELECT FOR", 10
    .byte "THE MAP.", 0
mb3:
    .byte "A CAVE-IN HAS BURIED THE", 10
    .byte "WAY DOWN UNDER TONS OF", 10
    .byte "ROCK AND SOIL.", 10, 10
    .byte "BLAST A PATH WITH GRENADES", 10
    .byte "(X BUTTON). HARD ROCK NEEDS", 10
    .byte "TWO BLASTS. GRAB EVERY", 10
    .byte "GRENADE YOU FIND.", 0
mb4:
    .byte "FOUR GENERATORS POWER THE", 10
    .byte "SECURITY GRID AHEAD.", 10, 10
    .byte "DESTROY ALL FOUR. THE", 10
    .byte "PLASMA RIFLE AND GRENADES", 10
    .byte "WORK BEST. THEN TAKE THE", 10
    .byte "EXIT LIFT.", 0
mb5:
    .byte "SOMETHING HUGE GUARDS THE", 10
    .byte "NEXT DESCENT: THE SENTINEL,", 10
    .byte "A HEAVY ARMORED WAR MACHINE.", 10, 10
    .byte "IT WAITS IN THE ARENA AT", 10
    .byte "THE BOTTOM. BULLETS GLANCE", 10
    .byte "OFF ITS ARMOR. USE PLASMA", 10
    .byte "AND THE RAILGUN.", 0
mb6:
    .byte "LASER GATES AND SEALED", 10
    .byte "BLAST DOORS BLOCK THE WAY.", 10, 10
    .byte "FIRE THE EMP LAUNCHER AT", 10
    .byte "4 SECURITY TERMINALS TO", 10
    .byte "OPEN THE EXIT. EMP ALSO", 10
    .byte "STUNS ROBOTS AND SHUTS", 10
    .byte "DOWN LASERS FOR A WHILE.", 0
mb7:
    .byte "THREE MINERS ARE HELD", 10
    .byte "CAPTIVE IN THE CRYSTAL", 10
    .byte "CAVES.", 10, 10
    .byte "REACH EACH ONE AND TOUCH", 10
    .byte "THEM TO BEAM THEM OUT.", 10
    .byte "THEN THE LIFT WILL OPEN.", 0
mb8:
    .byte "THE ENEMY HAS TRIGGERED", 10
    .byte "CHARGES. THE WHOLE LEVEL", 10
    .byte "IS COLLAPSING!", 10, 10
    .byte "REACH THE EXIT LIFT BEFORE", 10
    .byte "THE TIMER RUNS OUT.", 10
    .byte "DON'T STOP TO FIGHT.", 0
mb9:
    .byte "THE COMMANDER WHO ORDERED", 10
    .byte "YOUR FRIEND'S CAPTURE RUNS", 10
    .byte "THIS COMMAND POST.", 10, 10
    .byte "HE WEARS A RED BERET AND", 10
    .byte "HIS GUARDS DEFEND HARD", 10
    .byte "POSITIONS. TAKE HIM DOWN.", 0
mb10:
    .byte "THE FACILITY. YOUR FRIEND", 10
    .byte "IS LOCKED IN A CELL AT", 10
    .byte "THE BOTTOM OF THE COMPLEX.", 10, 10
    .byte "FIND A KEYCARD TO OPEN THE", 10
    .byte "CELL BLOCK DOOR. ROBOTS", 10
    .byte "GUARD EVERY HALL.", 10, 10
    .byte "BRING YOUR FRIEND HOME.", 0
