;-----------------------------------------------------------------------------------
;
; The usual norm is:
;   Don't change anything in this file. It's the heart of the system.
; But if you change something, be careful...
;
; Write your scripts in the scripts.nls file (open it from "Included Files" chooser)
;
; Please, read the Info Tab for instructions...
;
;-----------------------------------------------------------------------------------

extensions [ nw rnd]

__includes [ "scripts.nls" "custom.nls" ]

breed [nodes node]

nodes-own [
  degree
  betweenness
  eigenvector
  closeness
  clustering
  page-rank
  community
  phi
  visits
  rank
  new-rank
  infected
  typ
]

globals [
  diameter
  components
  ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main procedures
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to startup
  clear
  ask patch 8 0 [
    set plabel-color black
    set plabel "PLEASE, READ INFO TAB FOR INSTRUCTIONS"]
  wait 2
  clear
end

to clear
  clear-turtles
  clear-links
  clear-patches
  clear-all-plots
  set-default-shape nodes "circle"
  ask patches [set pcolor white]
end

; Auxiliary reports to split a string using a substring
to-report split-aux [s s1]
  ifelse member? s1 s
  [ let p position s1 s
    report (list (substring s 0 p) (substring s (p + (length s1)) (length s)))
  ]
  [ report (list s "")
  ]
end

to-report split [s s1]
  ifelse member? s1 s
  [
    let sp split-aux s s1
    report (fput (first sp) (split (last sp) s1))
  ]
  [ report (list s) ]
end

to-report join [s c]
  report reduce [[s1 s2] -> (word s1 c s2)] s
end

to-report replace [s c1 c2]
  report join (split s c1) c2
end

to-report store [val l]
  report lput val l
end

to inspect-node
  if mouse-down? [
    ask nodes [stop-inspecting self]
    let selected min-one-of nodes [distancexy mouse-xcor mouse-ycor]
    if selected != nobody [
      ask selected [
        if distancexy mouse-xcor mouse-ycor < 1 [inspect self]
      ]
    ]
    wait .2
  ]
end

to remove-node [prob]
  let selected ifelse-value (prob = "uniform")[one-of nodes] [rnd:weighted-one-of nodes [run-result prob]]
  ask selected  [die]
end

to plotTable [Lx Ly]
  set-current-plot "General"
  clear-plot
  set-plot-x-range (precision (min Lx) 2) (precision (max Lx) 2)
  set-plot-y-range (precision (min Ly) 2) (precision (max Ly) 2)
  (foreach Lx Ly
    [ [x y] ->
      plotxy x y
    ])
end

to print-csv [val]
  ifelse is-list? val
  [ print reduce [[x y] -> (word x ", " y)] val]
  [ print val]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Generators / Utilities
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to ER-RN [N p]
  create-nodes N [
    setxy random-xcor random-ycor
    set color red
  ]
  ask nodes [
    ask other nodes with [who < [who] of myself] [
      if random-float 1 < p [
        create-link-with myself
      ]
    ]
  ]
  post-process
end

to WS [N k p]
  create-nodes N [
    set color red
  ]
  layout-circle sort nodes max-pycor * 0.9
  let lis (n-values (K / 2) [ [i] -> i + 1 ])
  ask nodes [
    let w who
    foreach lis [ [i] -> create-link-with (node ((w + i) mod N)) ]
  ]
  rewire p
  post-process
end

to rewire [p]
  ask links [
    let rewired? false
    if (random-float 1) < p
    [
      ;; "a" remains the same
      let node1 end1
      ;; if "a" is not connected to everybody
      if [ count link-neighbors ] of node1 < (count nodes - 1)
      [
        ;; find a node distinct from node1 and not already a neighbor of node1
        let node2 one-of nodes with [ (self != node1) and (not link-neighbor? node1) ]
        ;; wire the new edge
        ask node1 [ create-link-with node2 [ set rewired? true ] ]
      ]
    ]
    ;; remove the old edge
    if (rewired?)
    [
      die
    ]
  ]
end

to BA-PA [N m0 m]
  create-nodes m0 [
    set color red
  ]
  ask nodes [
    create-links-with other nodes
  ]
  repeat (N - m0) [
    create-nodes 1 [
      set color blue
      let new-partners turtle-set map [find-partner] (n-values m [ [i] -> i ])
        create-links-with new-partners
    ]
  ]
  post-process
end

to-report find-partner
  report [one-of both-ends] of one-of links
end


to KE [N m0 mu]
  create-nodes m0 [
    set color red
  ]
  ask nodes [
    create-links-with other nodes
  ]
  let active nodes with [self = self]
  let no-active no-turtles
  repeat (N - m0) [
    create-nodes 1 [
      set color blue
      foreach shuffle (sort active) [ [ac] ->
        ifelse (random-float 1 < mu or count no-active = 0)
        [
          create-link-with ac
        ]
        [
          let cut? false
          while [not cut?] [
            let nodej one-of no-active
            let kj [count my-links] of nodej
            let S sum [count my-links] of no-active
            if (kj / S) > random-float 1 [
              create-link-with nodej
              set cut? true
            ]
          ]
        ]
      ]
      set active (turtle-set active self)
      let cut? false
      while [not cut?] [
        let nodej one-of active
        let kj [count my-links] of nodej
        let S sum [1 / (count my-links)] of active
        let P (1 / (kj * S))
        if P > random-float 1 [
          set no-active (turtle-set no-active nodej)
          set active active with [self != nodej]
          set cut? true
        ]
      ]
    ]
  ]
  post-process
end

to Geom [N r]
  create-nodes N [
    setxy random-xcor random-ycor
    set color blue
  ]
  ask nodes [
    create-links-with other nodes in-radius r
  ]
  post-process
end

to SCM [N g]
  create-nodes N [
    setxy random-xcor random-ycor
    set color blue
  ]
  let num-links (g * N) / 2
  while [count links < num-links ]
  [
    ask one-of nodes
    [
      let choice (min-one-of (other nodes with [not link-neighbor? myself])
                   [distance myself])
      if choice != nobody [ create-link-with choice ]
    ]
  ]
  post-process
end

to Grid [N M torus?]
  nw:generate-lattice-2d nodes links N M torus?
  ask nodes [set color blue]
  post-process
end

to BiP [nb-nodes nb-links]
  create-nodes nb-nodes [
    set typ one-of [0 1]
  ]
  let P0 nodes with [typ = 0]
  let P1 nodes with [typ = 1]
  repeat nb-links [
    ask one-of P0 [
      create-link-with one-of P1
    ]
  ]
  post-process
end

to Edge-Copying [Iter pncd k beta pecd]
  repeat Iter [
    ; Creation / Deletion of nodes
    ifelse random-float 1 > pncd
    [
      ask one-of nodes [die]
    ]
    [
      create-nodes 1 [
        setxy random-xcor random-ycor
        set color blue
      ]
    ]
    ; Edge Creation
    let v one-of nodes
    ifelse random-float 1 < beta
    [
      ;creation
      ask v [
        let other-k-nodes (other nodes) with [not link-neighbor? v]
        if count other-k-nodes >= k
        [
          set other-k-nodes n-of k other-k-nodes
        ]
        create-links-with other-k-nodes
      ]
    ]
    [
      ; copy
      let n k
      while [n > 0] [
        let u one-of other nodes
        let other-nodes (([link-neighbors] of u) with [self != v])
        if count other-nodes > k [
          set other-nodes n-of k other-nodes
        ]
        ask v [
          create-links-with other-nodes
        ]
        set n n - (count other-nodes)
        ]
    ]
    ; Creation / Deletion of edges
    ifelse random-float 1 < pecd [
      ask one-of nodes with [count my-links < (count nodes - 1)][
        let othernode one-of other nodes with [not link-neighbor? myself]
        create-link-with othernode
      ]
    ]
    [
      ask one-of links [die]
    ]
  ]
  post-process
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Centrality Measures
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; Takes a centrality measure as a reporter task, runs it for all nodes
;; and set labels, sizes and colors of turtles to illustrate result
to compute-centralities
  nw:set-context nodes links
  ask nodes [
    set degree (count my-links)
    set betweenness nw:betweenness-centrality
    set eigenvector nw:eigenvector-centrality
    set closeness nw:closeness-centrality
    set clustering nw:clustering-coefficient
    set page-rank nw:page-rank
  ]
  update-plots
end

to do-plot [Dk where]
  let M max Dk
  set-current-plot (word where " Distribution")
  set-plot-x-range 0 (ceiling M)
  set-plot-y-range 0 1
  set-histogram-num-bars 100
  histogram Dk
end

to plots
  clear-all-plots
  compute-centralities
  carefully [do-plot ([page-rank] of nodes) "PageRank"][]
  carefully [do-plot ([degree] of nodes) "Degree"][]
  carefully [do-plot ([nw:betweenness-centrality] of nodes) "Betweenness"][]
  carefully [do-plot ([nw:eigenvector-centrality] of nodes) "Eigenvector"][]
  carefully [do-plot ([nw:closeness-centrality] of nodes) "Closeness"][]
  carefully [do-plot ([nw:clustering-coefficient] of nodes) "Clustering"][]
  carefully [set diameter compute-diameter 1000][]
end


;; We want the size of the turtles to reflect their centrality, but different measures
;; give different ranges of size, so we normalize the sizes according to the formula
;; below. We then use the normalized sizes to pick an appropriate color.
to normalize-sizes-and-colors [c]
  if count nodes > 0 [
    let sizes sort [ size ] of nodes ;; initial sizes in increasing order
    let delta last sizes - first sizes ;; difference between biggest and smallest
    ifelse delta = 0 [ ;; if they are all the same size
      ask nodes [ set size 1 ]
    ]
    [ ;; remap the size to a range between 0.5 and 2.5
      ask nodes [ set size ((size - first sizes) / delta) * 1.5 + 0.4 ]
    ]
    ask nodes [ set color lput 200 extract-rgb scale-color c size 3.8 0] ; using a higher range max not to get too white...
  ]
end

; The diameter is cpmputed from a random search on distances between nodes
to-report compute-diameter [n]
  let s 0
  repeat n [
    ask one-of nodes [
      set s max (list s (nw:distance-to one-of other nodes))
    ]
  ]
  report s
end

to compute-components
  set components nw:weak-component-clusters
end

;to compute-phi
;  ask nodes [
;    set phi sum [exp -1 * ((nw:distance-to myself) ^ 2  / 100)] of nodes
;  ]
;end

to-report Average-Path-Length
  report nw:mean-path-length
end

to-report Average-Clustering
  report mean [clustering] of nodes
end

to-report Average-Betweenness
  report mean [betweenness] of nodes
end

to-report Average-Closeness
  report mean [closeness] of nodes
end

to-report Average-PageRank
  report mean [page-rank] of nodes
end

to-report Average-Eigenvector
  report mean [eigenvector] of nodes
end

to-report Average-Degree
  report mean [count my-links] of nodes
end

to-report Number-Nodes
  report count nodes
end

to-report Number-Links
  report count Links
end

to-report Density
  report 2 * (count links) / ( (count nodes) * (-1 + count nodes))
end

to-report All-Measures
  report (list Number-Nodes
               Number-Links
               Density
               Diameter
               length Components
               Average-Degree
               Average-Path-Length
               Average-Clustering
               Average-Betweenness
               Average-Eigenvector
               Average-Closeness
               Average-PageRank
               )
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Layouts & Visuals
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to layout [tl]
  if tl = "radial" and count nodes > 1 [
    layout-radial nodes links ( max-one-of nodes [ count my-links ] )
  ]
  if tl = "spring" [
    repeat 1000 [spring]
  ]
  if tl = "circle" [
    layout-circle sort nodes max-pycor * 0.9
  ]
  if tl = "bipartite" [
    layout-bipartite
  ]
  if tl = "tutte" [
    layout-circle sort nodes max-pycor * 0.9
    repeat 10 [
      layout-tutte max-n-of (count nodes * 0.5) nodes [ count my-links ] links 12
    ]
  ]
end

to layout-bipartite
  let P0 nodes with [typ = 0]
  let incp0 world-width / (1 + count p0)
  let P1 nodes with [typ = 1]
  let incp1 world-width / (1 + count p1)
  let x min-pxcor
  ask P0 [
    set color red
    setxy x max-pycor - 1
    set x x + incp0]
  set x min-pxcor
  ask P1 [
    set color blue
    setxy x min-pycor + 1
    set x x + incp1]
end

to refresh
  ask nodes [
    set size 0.7
    set label ""
;    set color red
  ]
  ask links [
    set color [150 150 150 100]
  ]
end

to post-process
  ask links [
    ;set color black
    set color [100 100 100 100]
  ]
  set diameter compute-diameter 1000
  compute-components
end

to spring
  layout-spring turtles links 0.03 3.64 0.416
  ask nodes [
    setxy (xcor * (1 - 0 / 1000)) (ycor * (1 - 0 / 1000))
  ]
end

to help
  user-message (word "                                      HELP                (Details in Info Tab)" "\n"
    "----------------------------------------------------------" "\n"
    "Generators:" "\n"
    "* ER-RN (N, p)                          * WS (N, k, p)" "\n"
    "* BA-PA (N, m0, m)                * KE (N, m0, mu)" "\n"
    "* Geom (N, r)                           * SCM (N, g)" "\n"
    "* Grid (N,M,t?)                         * BiP (N, M)" "\n"
    "* Edge-Copying (N, pn, k, b, pe)" "\n"
    "----------------------------------------------------------" "\n"
    "Utilities:" "\n"
    "* Compute-centralities           * Communities" "\n"
    "* PRank (Iter)                            * Rewire (p)" "\n"
    "* ContCA (Iter, pIn, p)             * Layout (type)" "\n"
    "* Print (measure)                     * Print-csv (data)" "\n"
    "* DiscCA (Iter, pIn, p0_ac, p1_ac)" "\n"
    "* Spread (Ni, ps, pr, pin, Iter)" "\n"
    "----------------------------------------------------------" "\n"
    "Global Measures:" "\n"
    "  Number-Nodes, Number-Links, Density, Average-Degree," "\n"
    "  Average-Path-Length, Diameter, Average-Clustering," "\n"
    "  Average-Betweenness, Average-Eigenvector," "\n"
    "  Average-Closeness, Average-PageRank, Components" "\n"
    "----------------------------------------------------------" "\n"
    "Layouts:  circle, radial, tutte, spring, bipartite" "\n"
    "----------------------------------------------------------" "\n"
    "* Save, Load" "\n"
    "* Export (view)" "\n"
    "    Views:  Degree, Clustering, Betweenness, Eigenvector, " "\n"
    "                 Closeness, PageRank" "\n"
    )
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Saving and loading of network files
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to save
  nw:set-context nodes links
  carefully [
    nw:save-graphml user-new-file
  ][]
end

to load
  clear
  nw:set-context nodes links
  nw:load-graphml user-file
  compute-centralities
end

to export [view]
  let file (word view "-" (replace date-and-time ":" "_") ".csv")
  set view (word view " Distribution")
  export-plot view file
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Page Rank
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to PRank [n]
  let damping-factor 0.85
  ;ask links [ set color gray set thickness 0 ]
  ask nodes [
    set rank 1 / count nodes
    set new-rank 0 ]
  repeat N [
    ask nodes
    [
      ifelse any? link-neighbors
      [
        let rank-increment rank / count link-neighbors
        ask link-neighbors [
          set new-rank new-rank + rank-increment
        ]
      ]
      [
        let rank-increment rank / count nodes
        ask nodes [
          set new-rank new-rank + rank-increment
        ]
      ]
    ]
    ask nodes
    [
      ;; set current rank to the new-rank and take the damping-factor into account
      set rank (1 - damping-factor) / count nodes + damping-factor * new-rank
    ]
  ]

  let total-rank sum [rank] of nodes
  let max-rank max [rank] of nodes
  ask nodes [
    set size 0.2 + 2 * (rank / max-rank)
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Spread
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to spread [N-mi ps pr pin Iter]
  let t 0
  set-current-plot "General"
  clear-plot
  foreach [["Green" green] ["Red" red] ["Blue" blue]] [ [c] ->
    create-temporary-plot-pen first c
    set-current-plot-pen first c
    set-plot-pen-color last c
    set-plot-pen-mode 0
  ]
  ask nodes [
    set infected 0
    set color green
  ]
  ask n-of N-mi nodes [
    set infected 1
    set color red
  ]
  repeat Iter [
    ask nodes with [infected = 1]
    [ ask link-neighbors with [infected = 0]
      [ if random-float 1 < ps
        [ set infected 1
          set color red
        ] ] ]
    ask nodes with [infected = 1]
    [ if random-float 1 < pr
      [ set color green
        set infected 0
        if random-float 1 < pin
        [ set color blue
          set infected 2
        ]
      ] ]
    set t t + 1
    set-current-plot-pen "Green"
    plotxy t count nodes with [infected = 0]
    set-current-plot-pen "Red"
    plotxy t count nodes with [infected = 1]
    set-current-plot-pen "Blue"
    plotxy t count nodes with [infected = 2]

    display
    wait 2 / Iter
  ]
end

to-report spread-summary
  let s count nodes with [infected = 0]
  let i count nodes with [infected = 1]
  let r count nodes with [infected = 2]
  report (list s i r)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Cellular Automata
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Uses Typ = [current-state new-state] to store the state of the node


; Discrete value states
; Iter - Number of iterations
; pI - Initial Probability of activation
; p0_ac - ratio of activated neighbors to activate if the node is 0
; p1_ac - ratio of activated neighbors to activate if the node is 1

to DiscCA [Iter pIn p0_ac p1_ac]
  set-current-plot "General"
  clear-plot
  set-plot-y-range 0 1
  let t 0
  ask nodes [
    ifelse random-float 1 < pIn
    [ set typ [1]]
    [ set typ [0]]
    set color ifelse-value (current_state = 0) [red][blue]
  ]
  repeat Iter [
    no-display
    ask nodes [
      let s current_state
      let pn 0
      if any? link-neighbors [
        set pn count (link-neighbors with [current_state = 1]) / count link-neighbors
      ]
      ifelse s = 0
      [
        ifelse pn >= p0_ac
        [ new-state 1 ]
        [ new-state 0 ]
      ]
      [
        ifelse pn >= p1_ac
        [ new-state 1 ]
        [ new-state 0 ]
      ]
    ]
    ask nodes [
      set-state
      set color ifelse-value (current_state = 0) [red][blue]
    ]
    plotxy t count (nodes with [current_state = 1]) / count nodes
    set t t + 1
    display
    ;wait .01
  ]
end

; Continuous value states
; Iter - Number of iterations
; pI - Initial Probability of activation
; p - ratio of memory in the new state

to ContCA [Iter pIn p]
  set-current-plot "General"
  clear-plot
  set-plot-y-range 0 1
  let t 0
  ask nodes [
    set typ (list random-float pIn)
    set color scale-color blue current_state 0 1
  ]
  repeat Iter [
    no-display
    ask nodes [
      let s current_state
      let pn sum ([current_state] of link-neighbors) / count link-neighbors
      new-state (p * current_state + (1 - p) * pn)
    ]
    ask nodes [
      set-state
    set color scale-color blue current_state 0 1
    ]
    plotxy t sum ([current_state] of nodes) / count nodes
    set t t + 1
    display
    ;wait .01
  ]
end

; Get the current state of the node
to-report current_state
  report first typ
end

; Set the new state of the node to s
to new-state [s]
  set typ (lput s typ)
end

; Move the new state to the current state
to set-state
  set typ (list (last typ))
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
0
10
1351
696
-1
-1
11.1
1
12
1
1
1
0
0
0
1
-60
60
-30
30
0
0
0
ticks
30.0

PLOT
262
696
522
876
Degree Distribution
Degree
Nb Nodes
0.0
50.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -7500403 true "" "histogram [count my-links] of nodes"

PLOT
3
698
263
858
Clustering distribution
Clustering
Nb Nodes
0.0
100.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -6459832 true "" "histogram [round (nw:clustering-coefficient * 100)] of nodes with [degree > 2]"

MONITOR
1360
253
1410
298
Nodes
Number-Nodes
0
1
11

MONITOR
1410
253
1460
298
Links
Number-Links
0
1
11

BUTTON
1359
150
1446
183
BA-PA
ba_pa
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1462
255
1697
300
Mean_Opinion
Mean_Opinion
13
1
11

PLOT
1359
298
1788
437
General
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
"default" 1.0 0 -16777216 true "" ""

SLIDER
1360
219
1532
252
num_nodes
num_nodes
5
1500
275.0
10
1
NIL
HORIZONTAL

BUTTON
1445
150
1507
183
ER-RN
er_rn
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1505
150
1568
183
WS
ws_
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1490
182
1552
215
Geom
geo
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1359
183
1422
216
Grid
grid_
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1369
15
1446
48
Start
Opinions Bias_ 0 2
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
1355
49
1527
82
Iterations
Iterations
0
250
51.0
1
1
NIL
HORIZONTAL

SLIDER
1355
85
1527
118
Bias_
Bias_
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
1355
115
1527
148
Memory
Memory
0
1
0.95
0.01
1
NIL
HORIZONTAL

SWITCH
1449
15
1556
48
Advertising
Advertising
0
1
-1000

CHOOSER
1525
49
1663
94
Ad_type
Ad_type
"random" "max_opinion" "min_opinion" "hubs"
0

CHOOSER
1525
95
1663
140
Change_model
Change_model
"voter" "biased_average" "degroot" "biased"
0

BUTTON
1425
183
1489
217
KE
ke_
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1556
15
1660
48
Reset
Reset
0
1
-1000

MONITOR
1538
491
1613
536
Avg Pth Lgth
Average-Path-Length
3
1
11

SWITCH
1538
220
1650
253
Continuous
Continuous
0
1
-1000

MONITOR
1536
442
1643
487
Opinion clustering
Mean_Opinion_Clustering
3
1
11

PLOT
1362
592
1607
770
Opinion clustering
ticks
opinion clustering
0.0
2.0
0.0
1.0
true
false
"" ""
PENS
"pen-0" 1.0 0 -16777216 true "" "plot Mean_Opinion_Clustering"

SLIDER
1360
440
1532
473
ad_targets
ad_targets
0
1000
100.0
20
1
NIL
HORIZONTAL

SLIDER
1360
480
1532
513
ad_effect
ad_effect
-1
1
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
1360
520
1532
553
ad_effectiveness
ad_effectiveness
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
1360
555
1532
588
ad_count
ad_count
0
100
5.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
# Complex Networks Toolbox

  1. Introduction
  1. The Interface
  1. Scripts
  1. Generators
    * Erdős-Rényi Random Network
    * Watts & Strogatz Small Worlds Networks
    * Barabasi & Albert Preferential Attachtment
    * Klemm and Eguílez Small-World-Scale-Free Network
    * Geometric Network
    * Spatially Clustered Network
    * Grid
    * Bipartite
    * Edge Copying Dynamics
  1. Global Measures
  1. Utilities
    * Layouts
    * Compute Centralities
    * Communities
  1. Dynamics
    * Page Rank
    * Spread of infection/message
    * Cellular Automata
  1. Input/Output
    * Save / Load GraphML
    * Export Distributions

## Introduction

This NetLogo model is a toy tool to launch experiments for __Complex Networks__. 

It provides some basic commands to generate and analyze small networks by using the most common and famous algorithms (random graphs, scale free networks, small world, etc). Also, it provides some methods to test dynamics on networks (spread processes, page rank, cellular automata,...).

All the funtionalities have been designed to be used as extended NetLogo commands. In this way, it is possible to create small scripts to automate the generating and analyzing process in an easier way. Of course, they can be used in more complex and longer NetLogo procedures, but the main aim in their design is to be used by users with no previous experience on this language (although, if you know how to program in NetLogo, you can probably obtain stronger results).  

You can find the las version of the tool in [this Github poject](https://github.com/fsancho/Complex-Network-Analysis).

![Github](http://www.cs.us.es/~fsancho/images/2017-01/github.png) 


In the next sections you can find some details about how to use it.

## The Interface

Although the real power of the system is obtained via scripting, and it is its main goal, the interface has been designed to allow some interactions and facilitate to handle the creation and analysis of the networks. Indeed, before launching a batch of experiments is a good rule to test some behaviours by using the interface and trying to obtain a partial view and understanding of the networks to be analyzed... in this way, you will spend less time in experiments that will not work as you expect.

![Interface](http://www.cs.us.es/~fsancho/images/2017-01/interface.png)

The interface has 3 main areas:

  1. __Network Representation__: In the left side. It has a panel where the network is represented and it allows one only interaction, to inspect node information (when the button Inspect Node is pressed). Under this panel some widgets to manage the visualization properties are located: selected layout and parameters for it.
  1. __Measures Panel__: In the right side. It contains a collection of plots where the several centralities are shown and some monitors with global information about the current network. The measures that are computed for every node are:
    * Degree
    * Clustering
    * Betweenness
    * Eigenvector
    * Closeness
    * Page-Rank

## Scripts

Use `scripts.nls` to write your customized scripts. In order to acces this file, you must go to Code Tab and then choose ´scripts.nls´ from Included Files chooser. You can add as many aditional files as you want if you need some order in your experiments and analysis (load them with the `__includes` command from main file).

![Scripts](http://www.cs.us.es/~fsancho/images/2017-01/scripts.jpg)

Remember that a script is only a NetLogo procedure, hence it must have the following structure:

    to script-name
      ... 
      Commands
      ...
    end

After defining your scripts, you can run them directly from the Command Center.

In tho document you can find specific network commands that can be used to write scripts for creating and analyzing networks. In fact, this scripts can be written using any NetLogo command, but in this library you can find some shortcuts to make easier the process.

Some of the useful NetLogo commands you will probably need are:

  * `let v val` : Create a new variable `v` and sets its value to `val`.
  * `set v val` : Change the value fo the variable `v` to `val`.
  * `[ ]`  : Empty list, to store values in a repetition
  * `range x0 xf incx` : Returns a ordered list of numbers from `x0` to `xf` with `incx` increments.
  * `foreach [x1....xn] [ [x] -> P1...Pk ]` : for each `x` in `[x0 ... xn]` it executes the comands `P1` to `Pk`. 
  * `repeat N [P1...Pk]` : Repeat the block of commands `P1` to `Pk`, `N` times.
  * `store val L` : Store value `val` in list `L`.
  * `mean/sum/max/min L` : Returns the mean/sum/max/min value of list `L`.
  * `print v` : Print value of `v` in the Output.
  * `print-csv v` : Print value of `v` in the Output as comma-separated-values (if `v` is a list).
  * `plotTable [x1...xn] [y1...yn]` : Plot the points `(x1,y1)...(xn,yn)`. 

You can combine both to move some parameter in the creation/analysis of the networks. In the next example we study how the diameter of a Scale Free Network (built with Barabasi-Albert algorithm) changes in function of the size of the network:

    foreach (range 10 1000 10)
    [ [N] ->
        clear
        BA-PA N 2 1
        print diameter
    ]

For example, the next script will perform a experiment moving a parameter from 0 to 0.01 with increments of 0.001, and for every value of this parameter it will prepare 10 networks to compute their diameter.

    to script5 
      clear 
      foreach (range 0 .01 .001)
      [ [p] ->
        print p
        repeat 10
        [
          clear 
          BA-PA 300 2 1
          ER-RN 0 p
          print diameter
        ]
      ]
    end

From the Output we can copy/export the printed values and then analyze them in any other analysis software (R, Python, NetLogo, Excel, etc.)

## Generators

The current generators of networks (following several algorithms to get different structures) are:

### Erdős-Rényi Random Network:

In fact this is the Gilbert variant of the model introduced by Erdős and Rényi. Each edge has a fixed probability of being present (p) or absent (1-p), independently of the other edges.

N - Number of nodes,
p - link probability of wiring

    ER-RN N p

![Erdos-Renyi](http://www.cs.us.es/~fsancho/images/2017-01/er-rn.jpg)

### Watts & Strogatz Small Worlds Networks:

The Watts–Strogatz model is a random graph generation model that produces graphs with small-world properties, including short average path lengths and high clustering. It was proposed by Duncan J. Watts and Steven Strogatz in their joint 1998 Nature paper.

Given the desired number of nodes N, the mean degree K (assumed to be an even integer), and a probability p, satisfying N >> K >> ln(N) >> 1, the model constructs an undirected graph with N nodes and NK/2 edges in the following way:

  1. Construct a regular ring lattice, a graph with N nodes each connected to K neighbors, K/2 on each side.
  2. Take every edge and rewire it with probability p. Rewiring is done by replacing (u,v) with (u,w) where w is chosen with uniform probability from all possible values that avoid self-loops (not u) and link duplication (there is no edge (u,w) at this point in the algorithm).

N - Number of nodes,
k - initial degree (even),
p - rewiring probability

    WS N k p

![WS](http://www.cs.us.es/~fsancho/images/2017-01/ws_1.png)

### Barabasi & Albert Preferential Attachtment:

The Barabási–Albert (BA) model is an algorithm for generating random scale-free networks using a preferential attachment mechanism. Scale-free networks are widely observed in natural and human-made systems, including the Internet, the world wide web, citation networks, and some social networks. The algorithm is named for its inventors Albert-László Barabási and Réka Albert.

The network begins with an initial connected network of m_0 nodes.

New nodes are added to the network one at a time. Each new node is connected to m <= m_0 existing nodes with a probability that is proportional to the number of links that the existing nodes already have. Formally, the probability p_i that the new node is connected to node i is

             k_i
    p_i = ----------
          sum_j(k_j)

where k_i is the degree of node i and the sum is made over all pre-existing nodes j (i.e. the denominator results in twice the current number of edges in the network). Heavily linked nodes ("hubs") tend to quickly accumulate even more links, while nodes with only a few links are unlikely to be chosen as the destination for a new link. The new nodes have a "preference" to attach themselves to the already heavily linked nodes.

N - Number of nodes,
m0 - Initial complete graph,
m - Number of links in new nodes

    BA-PA N m0 m

![BA](http://www.cs.us.es/~fsancho/images/2017-01/ba-pa.png)

### Klemm and Eguílez Small-World-Scale-Free Network:

The algorithm of Klemm and Eguílez manages to combine all three properties of many “real world” irregular networks – it has a high clustering coefficient, a short average path length (comparable with that of the Watts and Strogatz small-world network), and a scale-free degree distribution. Indeed, average path length and clustering coefficient can be tuned through a “randomization” parameter, mu, in a similar manner to the parameter p in the Watts and Strogatz model.

It begins with the creation of a fully connected network of size m0. The remaining N−m0 nodes in the network are introduced sequentially along with edges to/from m0 existing nodes. The algorithm is very similar to the Barabási and Albert algorithm, but a list of m0 “active nodes” is maintained. This list is biased toward containing nodes with higher degrees.

The parameter μ is the probability with which new edges are connected to non-active nodes. When new nodes are added to the network, each new edge is connected from the new node to either a node in the list of active nodes or with probability μ, to a randomly selected “non-active” node. The new node is added to the list of active nodes, and one node is then randomly chosen, with probability proportional to its degree, for removal from the list, i.e., deactivation. This choice is biased toward nodes with a lower degree, so that the nodes with the highest degree are less likely to be chosen for removal.

N -  Number of nodes,
m0 - Initial complete graph,
μ - Probability of connect with low degree nodes

    KE N m0 μ

![KE](http://www.cs.us.es/~fsancho/images/2017-01/ke.png)

### Geometric Network:

It is a simple algorithm to be used in metric spaces. It generates N nodes that are randomly located in 2D, and after that two every nodes u,v are linked if d(u,v) < r (a prefixed radius).

N - Number of nodes,
r - Maximum radius of connection

    Geom N r

![GN](http://www.cs.us.es/~fsancho/images/2017-01/geom.png)

### Spatially Clustered Network:

This algorithm is similar to the geometric one, but we can prefix the desired mean degree of the network, g. It starts by creating N randomly located nodes, and then create the number of links needed to reach the desired mean degree. This link creation is random in the nodes, but choosing the shortest links to be created from them.

N - Number of nodes,
g - Average node degree

    SCM N g

![SCM](http://www.cs.us.es/~fsancho/images/2017-01/scm.png)

### Grid (2D-lattice):

A Grid of N x M nodes is created. It can be chosen to connect edges of the grid as a torus (to obtain a regular grid).

M - Number of horizontal nodes
N - Number of vertical nodes
t? - torus?

    Grid N M t?

![Grid](http://www.cs.us.es/~fsancho/images/2017-01/grid.png)

### Bipartite:

Creates a Bipartite Graph with N nodes (randomly typed to P0 P1 families) and M random links between nodes of different families.

N - Number of nodes
M - Number of links

    BiP N M

![Bip](http://www.cs.us.es/~fsancho/images/2017-01/bip.png)

### Edge Copying Dynamics

The model introduced by Kleinberg et al consists of a itearion of three steps:

  1. __Node creation and deletion__: In each iteration, nodes may be independently created and deleted under some probability distribution. All edges incident on the deleted nodes are also removed. pncd - creation, (1 - pncd) deletion.

  1. __Edge creation__: In each iteration, we choose some node v and some number of edges k to add to node v. With probability β, these k edges are linked to nodes chosen uniformly and independently at random. With probability 1 − β, edges are copied from another node: we choose a node u at random, choose k of its edges (u, w), and create edges (v, w). If the chosen node u does not have enough edges, all its edges are copied and the remaining edges are copied from another randomly chosen node.

  1. __Edge deletion__: Random edges can be picked and deleted according to some probability distribution.


Iter - Number of Iterations
pncd - probability of creation/deletion random nodes
k - edges to add to the new node
beta - probability of new node to uniform connet/copy links
pecd - probability of creation/deletion random edges

    Edge-Copying Iter pncd k beta pecd

![Edge-Copying](http://www.cs.us.es/~fsancho/images/2017-01/edgecopy.png)

## Global Measures

The global measures we can take from any network are:

    Number-Nodes
    Number-Links
    Density
    Diameter
    Components
    Average-Degree
    Average-Path-Length
    Average-Clustering
    Average-Betweenness, 
    Average-Eigenvector, 
    Average-Closeness, 
    Average-Page-Rank
    All

Some of then need to be explicitely computed before they can de used (`computer-diameter`, `compute-components`). Some of them need to compute centralities before they can be used.  If you choose _All_, you obtain a list with all the measures of the network.

You can print any of them in the Output Window:
  
    Print measure


## Utilities

### Layouts

The system allows the following layouts:

    circle
    radial (centered in a max degree node)
    tutte
    spring (1000 iterations)
    bipartite

To use it from a script:

    layout type-string

For example:

    layout "circle"

![Layout](http://www.cs.us.es/~fsancho/images/2017-01/layouts.png)


### Compute Centralities
Current Centralities of every node:

    Degree,
    Betweenness, 
    Eigenvector, 
    Closeness, 
    Clustering, 
    Page-Rank

The way to compute all of them is by executing:

    compute-cantralities

![Centralities](http://www.cs.us.es/~fsancho/images/2017-01/medidas.png)

### Communities

Computes the communities of the current network using the Louvain method (maximizing the 
modularity measure of the network).

![Communities](http://www.cs.us.es/~fsancho/images/2017-01/communities.png)

### Remove Elements

You can remove one random node of the network by using `remove-node`, but you need to indicate the way this node is selected among all the nodes in the network. If you provide the name of a centrality measure, then the node is selected following a distribution proportional to that measure in every node. If you indicate "uniform", then all the nodes have the same chances to be selected. For example:

    remove-node "uniform"
    remove-node "page-rank"

## Dynamics

### Page Rank

Applies the Page Rank diffusion algorithm to the current Network a number of prefixed iterations.

Iter - Number of iterations

    PRank Iter

![PR](http://www.cs.us.es/~fsancho/images/2017-01/prank.png)

### Rewire

Rewires all the links of the current Network with a probability p. For every link, one of the nodes is fixed, while the other is rewired.

p - probability of rewire every link

    Rewire p

![Rewire](http://www.cs.us.es/~fsancho/images/2017-01/rewire.png)

### Spread of infection/message

Applies a spread/infection algorithm on the current network a number of iterations. It starts with a initial number of infected/informed nodes and in every step:

  1. The infected/informed nodes can spread the infection/message to its neighbors with probability ps (independently for every neighbor).

  1. Every infected/informed node can recover/forgot with a probability of pr.

  1. Every recovered node can become inmunity with a probability of pin. In this case, he will never again get infected / receive the message, and it can't spread it.

N-mi - Number of initial infected nodes
ps - Probability of spread of infection/message
pr - Probability od recovery / forgotten
pin - Probability of inmunity after recovering
Iter - Number of iterations

    Spread N-mi ps pr pin Iter

![Spread](http://www.cs.us.es/~fsancho/images/2017-01/spread.png)

### Cellular Automata

#### Discrete Totalistic Cellular Automata

The nodes have 2 possible values: on/off. In every step, every node changes its state according to the ratio of activated states.

Iter - Number of iterations
pIn - Initial Probability of activation
p0_ac - ratio of activated neighbors to activate if the node is 0
p1_ac - ratio of activated neighbors to activate if the node is 1

    DiscCA Iter pIn p0_ac p1_ac

#### Continuous Totalistic Cellular Automata

The nodes have a continuous possitive value for state: [0,..]. In every step, every node changes its state according to the states of the neighbors:

    s'(u) = p * s(u) + (1 - p) * avg {s(v): v neighbor of u}

Iter - Number of iterations
pIn - Initial Probability of activation
p - ratio of memory in the new state

    ContCA Iter pIn p

![CellularAutomata](http://www.cs.us.es/~fsancho/images/2017-01/contca.png)

## Input/Output

### Save GraphML / Load GraphML
Opens a Dialog windows asking for a file-name to save/load current network.

    Save
    Load

![GrpahML](https://upload.wikimedia.org/wikipedia/commons/thumb/9/92/CPT_Hardware-InputOutput.svg/500px-CPT_Hardware-InputOutput.svg.png)


### Export Distributions

You can export the several distributions of the measures for a single network:

    export view

Where view can be any of the following:

    Degree
    Clustering
    Betweenness
    Eigenvector
    Closeness
    PageRank

The program will automatically name the file with the distribution name and the date and time of exporting.

![Export](http://www.cs.us.es/~fsancho/images/2017-01/export.png)
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
Circle -7500403 true true 15 15 270
Circle -16777216 false false 13 13 272

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

circle1
false
0
Circle -7500403 true true 15 15 270

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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

curve
1.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
