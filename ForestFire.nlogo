;;;; Model based on Marten Scheffer's book "Critical Transitions"
;;;; Main idea is that trees start growing constantly (with probability P)
;;;; and also fires start constantly (with probability F),
;;;; so we can study how these two parameters drive system into critical state
;;;; where fires happen with size and frequency according The Power-Law.
;;;; Above Scheffer's idea I also employ idea of radiation:
;;;; -- heat from fire radiates, so it depends how much tree mass is at the patch and radiates to neighbors,
;;;;    probability of fire transmission is proportional to radiated heat (1/12 is radiated diagonally, 1/6 is radiated perpendicularly)
;;;;    from burnt mass, if heat is at least equal to 1 neighboring tree burns; note transmission is not driven by F
;;;; -- tree mass "radiates", ashes after burnt improve P (IDK how much now -- parameter?) and also neighboring tree-mass
;;;;    (it "radiates" with same principle 1/6 and 1/12, but still IDK how much and whether probability might be 100% -- parameter?)
;;;;

extensions [csv]

globals [
  initial-trees     ;; how many trees (green patches) we started with
  burned-trees      ;; how many have burned so far
  ticks-state       ;; for storing year of growing forest
  mass-before-step  ;;
  mass-before-burn  ;;
  mass-after-burn   ;;
  trees-before-step ;;
  trees-before-burn ;;
  trees-after-burn  ;;
  mass_grown        ;;
  mass_burnt        ;;
  trees_grown       ;;
  trees_burnt       ;;
  trees_count       ;;
  trees_mass        ;;
  ashes_count       ;;
  ashes_mass        ;;
  empty_count       ;;
  list_mass_grown        ;;
  list_mass_burnt        ;;
  list_trees_grown       ;;
  list_trees_burnt       ;;
  list_trees_count       ;;
  list_trees_mass        ;;
  list_ashes_count       ;;
  list_ashes_mass        ;;
  list_empty_count       ;;
  list-for-file
]

breed [fires fire]    ;; bright red turtles -- the leading edge of the fire
breed [embers ember]  ;; turtles gradually fading from red to near black
breed [trees tree]    ;; green turtles -- symbolyzes growing tree

turtles-own [mass]
patches-own [potential ashes]


to setup
  clear-all
  set-default-shape turtles "square"

  ;; setting constants
  set Mass-ashes-ratio 100 - Mass-heat-ratio
  set list_mass_grown []       ;;
  set list_mass_burnt []       ;;
  set list_trees_grown []      ;;
  set list_trees_burnt []      ;;
  set list_trees_count []      ;;
  set list_trees_mass []       ;;
  set list_ashes_count []      ;;
  set list_ashes_mass []       ;;
  set list_empty_count []      ;;
  set list-for-file [["Step" "mass_grown" "mass_burnt" "trees_grown" "trees_burnt" "trees_count" "trees_mass" "ashes_count" "ashes_mass" "empty_count"]]

  ;; make some green trees
  ask patches with [(random-float 100) < Initial-density] [
    sprout-trees 1 [
      set mass round random-exponential 3
      set color green - ln (mass + 1) + 2
      set pcolor green
    ]
  ]

  reset-ticks
end


to go
  ;; Saving state at start of step
  set mass-before-step sum [mass] of trees
  set trees-before-step count trees

  to-grow
  to-seed

  ;; Saving state in the middle -- after growing, before burning
  set mass-before-burn sum [mass] of trees
  set trees-before-burn count trees

  to-fire

  ;; Saving state in the middle -- after growing, before burning
  set mass-after-burn sum [mass] of trees
  set trees-after-burn count trees

  ;; Compute burns and growns
  set mass_grown mass-before-burn - mass-before-step      ;;
  set mass_burnt mass-before-burn - mass-after-burn       ;;
  set trees_burnt trees-before-burn - trees-after-burn    ;;
  set trees_grown trees-before-burn - trees-before-step   ;;
  set trees_count count patches with [pcolor = green]     ;;
  set trees_mass sum [mass] of trees                      ;;
  set ashes_count count patches with [pcolor = 32]        ;;
  set ashes_mass sum [ashes] of patches                   ;;
  set empty_count count patches with [pcolor = black]     ;;

  tick

  ;; Lists
  if ticks >= Transiency [
    set list_mass_grown lput mass_grown list_mass_grown       ;;
    set list_mass_burnt lput mass_burnt list_mass_burnt       ;;
    set list_trees_grown lput trees_grown list_trees_grown    ;;
    set list_trees_burnt lput trees_burnt list_trees_burnt    ;;
    set list_trees_count lput trees_count list_trees_count    ;;
    set list_trees_mass lput trees_mass list_trees_mass       ;;
    set list_ashes_count lput ashes_count list_ashes_count    ;;
    set list_ashes_mass lput ashes_mass list_ashes_mass       ;;
    set list_empty_count lput empty_count list_empty_count    ;;
    set list-for-file lput (list ticks
      precision mass_grown 3
      precision mass_burnt 3
      trees_grown
      trees_burnt
      trees_count
      precision trees_mass 3
      ashes_count
      precision ashes_mass 3
      empty_count) list-for-file
  ]

  ;; Stopping
  if ticks >= Stop-at [
    csv:to-file (word "old_" (P * 1000) "_" (F * 1000) "_" Tree-radiation "_" Mass-heat-ratio "_" Mass-ashes-ratio "_" Ashes-retention-ratio "_" Ashes-mass-ratio "_" Transiency "_" Stop-at ".csv") list-for-file
    stop
  ]

end


to to-grow
  ask trees [
    set mass mass + 1
    ;set label mass
    set color green - ln (mass + 1) + 2
    set pcolor green
  ]
end


to to-seed
  ask patches with [not any? trees-here] [
    set potential (sum [mass] of trees-on neighbors + sum [mass] of trees-on neighbors4) / 12 * Tree-radiation / 100  ;; Then NEIS4 have twice a weight
    set potential potential + ashes
    set potential potential + P ;/ (ticks + 1) ;; adding basic probability of seeding
    if (random-float 100) <= potential [
      sprout-trees 1 [
        set mass ashes * Ashes-mass-ratio / 100
        set color green - ln (mass + 1) + 2
      ]
      set ashes 0
      set pcolor green
    ]
    set ashes ashes * Ashes-retention-ratio / 100
  ]
end


to to-fire
  ;; Starting fires
  ;;; Preparation
  if Watch-fire [
    set ticks-state ticks
    reset-ticks
  ]

  ;;; Mere starting
  ask trees with [(random-float 100) <= F] [
    set breed fires
    set color red
  ]

  ;; Burning of forest itself
  burning

  ;; At the end reset ticks to the original value
  if Watch-fire [
    reset-ticks
    tick-advance ticks-state
  ]
end


to burning
  while [any? fires] [
    ask fires [
      ifelse BurnNeis4 [
        ask trees-on neighbors4 [
          set breed fires
          set color red
        ]
      ][
        ask trees-on neighbors [
          if random-float 1 < ([mass] of myself / 12 * Mass-heat-ratio / 100) [
            set breed fires
            set color red
          ]
        ]
        ask trees-on neighbors4 [  ;; NEIS4 get twice a heat radiation, that's why we face them with same probability again
          if random-float 1 < ([mass] of myself / 12 * Mass-heat-ratio / 100) [
            set breed fires
            set color red
          ]
        ]
      ]
      set breed embers
    ]
    fade-embers
    if Watch-fire [tick]
  ]
  while [any? embers] [
    fade-embers
    if Watch-fire [tick]
  ]
end


;; achieve fading color effect for the fire as it burns
to fade-embers
  ask embers [
    set color color - 0.3  ;; make red darker
    if color <= red - 3.3 [  ;; are we almost at black?
      ask patch-here [set ashes [mass] of myself * Mass-ashes-ratio / 100]
      set pcolor 32
      die
    ]
  ]
end


; Copyright 1997 Uri Wilensky, 2024 FranČesko.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
200
10
808
619
-1
-1
2.0
1
10
1
1
1
0
0
0
1
0
299
0
299
1
1
1
ticks
30.0

MONITOR
1211
116
1299
161
percent burned
(trees-before-burn - trees-after-burn) / count patches * 100
1
1
11

SLIDER
1211
85
1396
118
Initial-density
Initial-density
0.0
99.0
20.0
1.0
1
%
HORIZONTAL

BUTTON
61
76
116
112
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
7
76
62
112
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
8
195
180
228
P
P
0
10
10.0
.001
1
NIL
HORIZONTAL

SLIDER
8
236
180
269
F
F
0
5
0.01
.001
1
NIL
HORIZONTAL

TEXTBOX
8
277
158
342
P - probability that new tree starts growing at empty patch\n\nF - probability of spontaneous fire of given tree
10
0.0
1

PLOT
817
10
1204
203
Tree mass grown & burnt
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Tree mass" 1.0 0 -10899396 true "" "plot  (1 + mass_grown)"
"Burnt mass" 1.0 0 -2674135 true "" "plot  (1 + mass_burnt)"

SLIDER
2
353
174
386
Tree-radiation
Tree-radiation
0
100
0.0
1
1
NIL
HORIZONTAL

BUTTON
116
78
171
111
1-Step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
4
441
176
474
Mass-ashes-ratio
Mass-ashes-ratio
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
8
486
183
519
Ashes-retention-ratio
Ashes-retention-ratio
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
6
398
178
431
Mass-heat-ratio
Mass-heat-ratio
0
100
100.0
1
1
NIL
HORIZONTAL

PLOT
818
228
1360
550
Grown mass and size of fire (ln)
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Trees" 1.0 2 -10899396 true "" "plotxy ln (1 + trees_grown) ln (1 + trees_burnt)"
"Mass" 1.0 2 -6459832 true "" "plotxy ln (1 + mass_grown) ln (1 + mass_burnt)"
"Diagonal" 1.0 0 -16777216 true "" "(foreach range 17 range 17 [[x y] -> plotxy x y])"

SWITCH
10
606
121
639
BurnNeis4
BurnNeis4
0
1
-1000

SLIDER
11
528
183
561
Ashes-mass-ratio
Ashes-mass-ratio
0
100
0.0
1
1
NIL
HORIZONTAL

PLOT
1470
71
1670
221
Tree-Mass histogram
NIL
NIL
0.0
500.0
0.0
10.0
true
false
"" ""
PENS
"default" 10.0 1 -16777216 true "" "histogram [(mass )] of trees"

INPUTBOX
822
563
977
623
Stop-at
1100.0
1
0
Number

SWITCH
31
667
145
700
Watch-fire
Watch-fire
1
1
-1000

PLOT
1467
241
1667
391
Ashes-mass histogram
NIL
NIL
0.0
100.0
0.0
10.0
true
false
"" ""
PENS
"default" 10.0 1 -16777216 true "" "histogram [ashes] of patches with [ashes > 0]"

SLIDER
992
563
1164
596
Transiency
Transiency
0
100
100.0
1
1
NIL
HORIZONTAL

PLOT
1470
413
1670
563
Histogram trees-counts
NIL
NIL
18000.0
100000.0
0.0
10.0
true
false
"" ""
PENS
"default" 10000.0 1 -16777216 true "" "histogram list_trees_count"

PLOT
1467
594
1667
744
Histogram trees-burnt
NIL
NIL
0.0
17000.0
0.0
10.0
true
false
"" ""
PENS
"default" 1000.0 1 -16777216 true "" "histogram list_trees_burnt"

@#$#@#$#@
## WHAT IS IT?

This project simulates the spread of a fire through a forest.  It shows that the fire's chance of reaching the right edge of the forest depends critically on the density of trees. This is an example of a common feature of complex systems, the presence of a non-linear threshold or critical parameter.

## HOW IT WORKS

The fire starts on the left edge of the forest, and spreads to neighboring trees. The fire spreads in four directions: north, east, south, and west.

The model assumes there is no wind.  So, the fire must have trees along its path in order to advance.  That is, the fire cannot skip over an unwooded area (patch), so such a patch blocks the fire's motion in that direction.

## HOW TO USE IT

Click the SETUP button to set up the trees (green) and fire (red on the left-hand side).

Click the GO button to start the simulation.

The DENSITY slider controls the density of trees in the forest. (Note: Changes in the DENSITY slider do not take effect until the next SETUP.)

## THINGS TO NOTICE

When you run the model, how much of the forest burns. If you run it again with the same settings, do the same trees burn? How similar is the burn from run to run?

Each turtle that represents a piece of the fire is born and then dies without ever moving. If the fire is made of turtles but no turtles are moving, what does it mean to say that the fire moves? This is an example of different levels in a system: at the level of the individual turtles, there is no motion, but at the level of the turtles collectively over time, the fire moves.

## THINGS TO TRY

Set the density of trees to 55%. At this setting, there is virtually no chance that the fire will reach the right edge of the forest. Set the density of trees to 70%. At this setting, it is almost certain that the fire will reach the right edge. There is a sharp transition around 59% density. At 59% density, the fire has a 50/50 chance of reaching the right edge.

Try setting up and running a BehaviorSpace experiment (see Tools menu) to analyze the percent burned at different tree density levels. Plot the burn-percentage against the density. What kind of curve do you get?

Try changing the size of the lattice (`max-pxcor` and `max-pycor` in the Model Settings). Does it change the burn behavior of the fire?

## EXTENDING THE MODEL

What if the fire could spread in eight directions (including diagonals)? To do that, use `neighbors` instead of `neighbors4`. How would that change the fire's chances of reaching the right edge? In this model, what "critical density" of trees is needed for the fire to propagate?

Add wind to the model so that the fire can "jump" greater distances in certain directions.

Add the ability to plant trees where you want them. What configurations of trees allow the fire to cross the forest? Which don't? Why is over 59% density likely to result in a tree configuration that works? Why does the likelihood of such a configuration increase so rapidly at the 59% density?

The physicist Per Bak asked why we frequently see systems undergoing critical changes. He answers this by proposing the concept of [self-organzing criticality] (https://en.wikipedia.org/wiki/Self-organized_criticality) (SOC). Can you create a version of the fire model that exhibits SOC?

## NETLOGO FEATURES

Unburned trees are represented by green patches; burning trees are represented by turtles.  Two breeds of turtles are used, "fires" and "embers".  When a tree catches fire, a new fire turtle is created; a fire turns into an ember on the next turn.  Notice how the program gradually darkens the color of embers to achieve the visual effect of burning out.

The `neighbors4` primitive is used to spread the fire.

You could also write the model without turtles by just having the patches spread the fire, and doing it that way makes the code a little simpler.   Written that way, the model would run much slower, since all of the patches would always be active.  By using turtles, it's much easier to restrict the model's activity to just the area around the leading edge of the fire.

See the "CA 1D Rule 30" and "CA 1D Rule 30 Turtle" for an example of a model written both with and without turtles.

## RELATED MODELS

* Percolation
* Rumor Mill

## CREDITS AND REFERENCES

https://en.wikipedia.org/wiki/Forest-fire_model

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1997).  NetLogo Fire model.  http://ccl.northwestern.edu/netlogo/models/Fire.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1997 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was developed at the MIT Media Lab using CM StarLogo.  See Resnick, M. (1994) "Turtles, Termites and Traffic Jams: Explorations in Massively Parallel Microworlds."  Cambridge, MA: MIT Press.  Adapted to StarLogoT, 1997, as part of the Connected Mathematics Project.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2001.

<!-- 1997 2001 MIT -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
set density 60.0
setup
repeat 180 [ go ]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="firstExperiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="P">
      <value value="0"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="F">
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tree-radiation">
      <value value="10"/>
      <value value="40"/>
      <value value="70"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mass-heat-ratio">
      <value value="10"/>
      <value value="40"/>
      <value value="70"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mass-ashes-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ashes-retention-ratio">
      <value value="10"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ashes-mass-ratio">
      <value value="10"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-density">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transiency">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stop-at">
      <value value="3100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="BurnNeis4">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Watch-fire">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="secondtExperiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="P">
      <value value="0"/>
      <value value="0.001"/>
      <value value="0.1"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="F">
      <value value="0.001"/>
      <value value="0.1"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tree-radiation">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mass-heat-ratio">
      <value value="10"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mass-ashes-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ashes-retention-ratio">
      <value value="10"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ashes-mass-ratio">
      <value value="10"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-density">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transiency">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stop-at">
      <value value="1100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="BurnNeis4">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Watch-fire">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="oldtExperiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="P">
      <value value="0"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="F">
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="BurnNeis4">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tree-radiation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mass-heat-ratio">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mass-ashes-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ashes-retention-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ashes-mass-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial-density">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transiency">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stop-at">
      <value value="1100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Watch-fire">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
