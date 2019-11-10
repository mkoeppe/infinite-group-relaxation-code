import cutgeneratingfunctionology.igp as igp; from cutgeneratingfunctionology.igp import *

load("survey_graphics/tab_functions.sage")

parametric=True

h = kzh_minimal_has_only_crazy_perturbation_1(parametric=parametric)

try:
    logging.info("Running facet_test")
    facet_test(h, known_extreme=True)
except NotImplementedError as e:
    logging.info("Exception: {} (this is normal)".format(e))
    pass

with open('/Users/mkoeppe/w/papers/basu-hildebrand-koeppe-papers/algo-paper/tab_kzh_minimal_has_only_crazy_perturbation_finite_system.tex', 'w') as f:
    f.write(r'%% Automatically generated.' + '\n')
    caption = r'Homogeneous linear system for $\bar\pi$ in the proof of \autoref{lemma:discontinuous_examples_2}'
    format = r'*3{>{\tiny$}c<{$}@{}}@{\quad}*{39}{>{\tiny$}c<{$}@{}}@{\quad}*2{>{\tiny$}c<{$}@{}}'
    extra_caption = r'. $\bar\pi$ is evaluated at breakpoints and midpoints of intervals. Abbreviations: ${+} = 1$, ${-} = -1$, ${\cdot} = 0$'
    f.write(tabulate_finite_system(h, label='tab:kzh_minimal_has_only_crazy_perturbation_finite_system', format=format, caption=caption, extra_caption=extra_caption))