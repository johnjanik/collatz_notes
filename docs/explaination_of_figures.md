### The following is a list of figures and their explainations. 

1. diophantine_branch_k729.png — main branch cell topology (k=81 reference, k=729 p_odd, cell type map, foliation distances, summary)                                                                                                             
2. diophantine_k729_zoom.png — zoomed branch cell structure near foliation lines                                                                                                                                                                  
3. diophantine_foliation_depletion.png — enrichment, p_odd distributions, Diophantine error vs singular density                                                                                                                                   
4. diophantine_k729_structure.png — spatial structure vs foliation distance
5. diophantine_transitions.png — new: transition valence map, "11" successor analysis, k=81 vs k=729 transition comparison, shadow offset profile

The foliation is the family of parallel lines overlaid on the plot (red dashed and green dotted). They're a fixed geometric structure on the torus — think of them as the "grain" of  
  the dynamics.
                                                                                                                                                                                        
  What you're seeing is the edge structure of the branch locus, and it's telling you something specific:

  When an odd step happens at cell (r2, r3), the successor lands at (r2, r3+1) — shifted one cell to the right in the ν₃ direction. Whether that successor is branch (gold) or pure_even
   (blue) depends on whether (r2, r3+1) is still inside the branch strip.

  - Blue lower bound: the bottom edge of the strip. Cells there are already at the strip boundary, and shifting +1 in r3 pushes the successor outside the branch region into pure_even
  territory. So the entire lower edge shows blue successors.
  - Blue tendrils peeling off upward-right: these are places where the branch strip locally narrows. The successor at (r2, r3+1) falls outside the branch region at these pinch points.
  The tendrils trace the direction along which the strip thins — which should follow the stable foliation direction (slope −1/log₂3 ≈ −0.631 in the data coordinates, steep negative
  slope in the plot).

  This connects to the mathematical motivation in the code header: "the foliations are measured foliations with finitely many singularities (the prong-type singularities at parity
  transitions)." The tendrils are visual signatures of those prong singularities — places where the branch locus boundary interacts with the stable foliation leaves.

  Would it be useful to overlay the stable foliation (slope −log₂3) on this panel as well, to check whether the tendrils align with the stable leaves?
