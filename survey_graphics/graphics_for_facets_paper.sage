load("survey_graphics/graphics_for_algo_paper_init.sage")

try:
    destdir = facets_paper_output_dir  # defined in config.sage
except Exception:
    #destdir = "survey_graphics/algo_paper_graphics/"
    destdir = "/Users/yzh/Dropbox/basu-hildebrand-koeppe-papers-for-yuan/algo-paper/graphics-for-facets-paper/"

########## facet paper ###########

def save_graphics(g, fname, **kwds):
    fname = destdir + fname + ftype
    logging.warn('Saving "{}"'.format(fname))
    all_kwds = copy(kwds)
    all_kwds.update(save_kwds)
    g.save(fname, **all_kwds)

igp.plot_limit_cone_style = 'arrows'

# figures for 1/2 linewidth
igp.show_plots_figsize = 8
paper_plot_kwds['fontsize'] = 20

ftype = ".pdf"

save_kwds = {'figsize': igp.show_plots_figsize}

bb = point((1.1, 0.5), color='white', alpha=0)

name = 'hildebrand_discont_3_slope_1'
h = eval(name)()
hl = discontinuous_facets_paper_example_psi_prime()
liftname = ''

Gh = (plot_2d_diagram_additive_domain_sans_limits(h, show_function=False) + plot_function_at_borders(h, color='black', thickness=2) + bb)
save_graphics(Gh, '{}{}-2d_diagram_sans_limits'.format(name, liftname), **paper_plot_kwds)
Ghl = (plot_2d_diagram_additive_domain_sans_limits(hl, show_function=False) + plot_function_at_borders(hl, color='red', thickness=2) + bb)
## (Gh + Ghl).save(destdir + '{}{}-lifted-2d_diagram_sans_limits'.format(name, liftname) + ftype, figsize=igp.show_plots_figsize, **paper_plot_kwds)
save_graphics(Ghl, '{}{}-lift1-2d_diagram_sans_limits'.format(name, liftname), **paper_plot_kwds)

Gh += plot_2d_diagram_with_cones(h, show_function=False)
save_graphics(Gh, '{}{}-2d_diagram_plus_limits'.format(name, liftname), **paper_plot_kwds)
Ghl += plot_2d_diagram_with_cones(hl, show_function=False)
## (Gh + Ghl).save(destdir + '{}{}-lifted-2d_diagram_plus_limits'.format(name, liftname) + ftype, figsize=igp.show_plots_figsize, **paper_plot_kwds)
save_graphics(Ghl, '{}{}-lift1-2d_diagram_plus_limits'.format(name, liftname), **paper_plot_kwds)


####

# figures for full linewidth
igp.show_plots_figsize = 12
paper_plot_kwds['fontsize'] = 16
igp.plot_function_at_borders_kwds = { 'thickness': 2 }
igp.plot_limit_cone_arrow_distance = 8.0/igp.show_plots_figsize * plot_limit_cone_arrow_distance
igp.plot_limit_cone_arrow_length = 8.0/igp.show_plots_figsize * plot_limit_cone_arrow_length

ftype = ".png"

h = kzh_minimal_has_only_crazy_perturbation_1()
x = h.end_points()
l=x[17]; u = x[18]; ll = x[19]; uu=x[20]; f=x[37]
assert l + uu == f and u + ll == f
w = u - l
color1 = 'lightblue'
color2 = 'mediumslateblue'
color3 = 'darkblue'

igp.plot_2d_complex_continuous_kwds = igp.plot_2d_complex_discontinuous_kwds = {'color': 'grey', 'alpha': 0.3, 'zorder': -2}   # 'linestyle': 'dotted',  'zorder': -10

g = plot_2d_complex(h)
g_at_borders = plot_function_at_borders(h, covered_components=generate_covered_components(h))
g += g_at_borders
tk=[0,l,u,ll,uu,f,1];
tkfx=[0,"$l$","$u$","$f-u$","","$f$","$1$"]  # omit f-l (doesn't fit)
tkfy=[0,"$l$","$u$","$f-u$","$f-l$","$f$",""]  # omit 1 (doesn't fit)
save_kwds = {'ticks': [tk, tk], 'tick_formatter': [tkfx, tkfy], 'show_legend': False,
             'figsize': igp.show_plots_figsize}
save_kwds.update(paper_plot_kwds)

all_special_faces = set(generate_faces_with_projections_intersecting(h, h.special_intervals, break_symmetry=False))
for F in all_special_faces:
    if F.is_2D():
        if number_of_projections_intersecting(F, h.special_intervals) == 1:
            g += F.plot(zorder=-5, fill_color=color1)
        else:
            g += F.plot(zorder=-5, fill_color=color2)
    else:
        g += F.plot(zorder=0, rgbcolor=color3, edge_thickness=1)

save_graphics(g, '2d_crazy_nf_with_func')

#g = plot_2d_diagram(h, colorful=True, show_projections=False)
g = plot_2d_diagram_additive_domain_sans_limits(h, show_function=False) + plot_2d_diagram_with_cones(h, show_function=False) + g_at_borders
components = generate_covered_intervals(h)
symbolic = generate_symbolic(h, components)
M, vs = generate_additivity_equations(h, symbolic, reduce_system=True, return_vertices=True)
vs = [ v for v in vs if isinstance(v, tuple) ]   # omit special labels 'f', '1'
g += sum(plot_limit_cone_of_vertex(x, y, epstriple_to_cone((xeps, yeps, zeps)), color='black') for (x, y, z, xeps, yeps, zeps) in vs)
save_graphics(g, 'kzh_crazy_2d_with_func')

igp.strategical_covered_components = False
h = kzh_minimal_has_only_crazy_perturbation_1()
plot_background = polygon2d([[0,0], [0,1], [1,1], [1,0]], fill=False, color='grey') + g_at_borders
generate_directed_move_composition_completion(h, max_num_rounds=0, error_if_max_num_rounds_exceeded=False, plot_background=plot_background)
g = h._completion.plot()
save_graphics(g, 'kzh_crazy_moves_with_func')

igp.strategical_covered_components = True
h = kzh_minimal_has_only_crazy_perturbation_1()
generate_directed_move_composition_completion(h, max_num_rounds=0, error_if_max_num_rounds_exceeded=False, plot_background=plot_background)
g = h._completion.plot()
save_graphics(g, 'kzh_crazy_moves_strategic_with_func')

h = kzh_minimal_has_only_crazy_perturbation_1()
generate_directed_move_composition_completion(h, plot_background=plot_background)
g = h._completion.plot()
save_graphics(g, 'kzh_crazy_completion_with_func')
