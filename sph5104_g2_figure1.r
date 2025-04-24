# If not installed:
# install.packages("DiagrammeR")
library(DiagrammeR)
library(readxl)

# Read xls file
df <- read_excel("Downloads/figure1numbers.xls")

# Extract the counts (assuming exactly one row of data)
v_all_icu      <- df$step0_all_icu
v_adult_icu    <- df$step1_adult_icu
v_nonpregnant  <- df$step2_nonpregnant
v_mi           <- df$step3_mi
v_hba1c        <- df$step4_hba1c
v_final_cohort <- df$step5_final_cohort

# Calculate exclusion numbers as the difference between consecutive stages:
excl1 <- v_all_icu - v_adult_icu
excl2 <- v_adult_icu - v_nonpregnant
excl3 <- v_nonpregnant - v_mi
excl4 <- v_mi - v_hba1c
excl5 <- v_hba1c - v_final_cohort

# Build a DiagrammeR graph with both inclusion nodes (main flow)
# and exclusion nodes (branching out at each step)
diagram_code <- paste0("
digraph flowchart {
  // Global graph attributes
  graph [rankdir = TB, fontsize=10];
  
  // Node styling
  node [shape = box,
        style = filled,
        fillcolor = white,
        fontname = Helvetica,
        fontsize = 12,
        penwidth = 1.0];
  
  // Define main flow nodes
  A [label = 'Step 0: All ICU Patients\\n(n = ", v_all_icu, ")'];
  B [label = 'Step 1: Adults\\n(n = ", v_adult_icu, ")'];
  C [label = 'Step 2: Non-pregnant Patients\\n(n = ", v_nonpregnant, ")'];
  D [label = 'Step 3: Patients with MI\\n(n = ", v_mi, ")'];
  E [label = 'Step 4: Patients with HbA1c Data\\n(n = ", v_hba1c, ")'];
  F [label = 'Step 5: Final Cohort\\n(n = ", v_final_cohort, ")'];
  
  
  // Define exclusion nodes (branch results)
  B_excl [label = 'Records excluded due to pregnancy\\n(n = ", excl2, ")'];
  C_excl [label = 'Records excluded due to absence of MI diagnosis\\n(n = ", excl3, ")'];
  D_excl [label = 'Records excluded for missing HbA1c data\\n(n = ", excl4, ")'];
  E_excl [label = 'Records excluded incomplete data\\n(n = ", excl5, ")'];
  
  // Align each main node with its exclusion branch on the same horizontal rank
  { rank = same; B; B_excl; }
  { rank = same; C; C_excl; }
  { rank = same; D; D_excl; }
  { rank = same; E; E_excl; }
  
  // Connect main nodes with solid arrows (for included counts)
  A -> B [label = 'Included', fontsize=10];
  B -> C [label = 'Included', fontsize=10];
  C -> D [label = 'Included', fontsize=10];
  D -> E [label = 'Included', fontsize=10];
  E -> F [label = 'Included', fontsize=10];
  
  // Draw dashed arrows for exclusions (using constraint=false to avoid affecting layout)
  B -> B_excl [label = 'Excluded', style = dashed, constraint = false, fontsize=10, fontcolor = red];
  C -> C_excl [label = 'Excluded', style = dashed, constraint = false, fontsize=10, fontcolor = red];
  D -> D_excl [label = 'Excluded', style = dashed, constraint = false, fontsize=10, fontcolor = red];
  E -> E_excl [label = 'Excluded', style = dashed, constraint = false, fontsize=10, fontcolor = red];
}
")

# Render the flow diagram
grViz(diagram_code)

