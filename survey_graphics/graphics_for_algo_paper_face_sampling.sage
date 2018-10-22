## Face sampling

load("survey_graphics/graphics_for_algo_paper_init.sage")


igp.show_plots_figsize = 10


def sampled_interval(I, num_samples=5):
    a, b = interval_to_endpoints(I)
    delta = (b - a) / num_samples
    return [ a + i * delta for i in range(num_samples+1) ]

def sampled_face(F, num_samples=5, translations=True, reflections=True):
    I, J, K = F.minimal_triple
    result = []
    if translations:
        result = [ Face([[x], J, K]) for x in sampled_interval(I, num_samples) ] \
          + [ Face([I, [y], K]) for y in sampled_interval(J, num_samples) ]
    if reflections:
        result += [ Face([I, J, [z]]) for z in sampled_interval(K, num_samples) ]
    return result

def symmetric_sampled_faces(F, Fprime, num_samples=4, **kwds):
    E_list = [ E for E in sampled_face(F, num_samples, **kwds) if E.is_1D() ]
    E_list += [ E for E in sampled_face(Fprime, num_samples, **kwds) if E.is_1D() ]
    return E_list

def ticks_keywords_for_faces(faces):
    L = []
    for F in faces:
        L += flatten(F.minimal_triple)
    L = unique_list(sorted(L))
    tick_formatter = [ "$%s$" % latex(x) for x in L ]
    return { 'ticks': (L, L), 'tick_formatter': (tick_formatter, tick_formatter) }

def plot_sampled_stuff(F_list, E_list, name):
    fname = destdir + name + "-%s.png"
    fname_sampled = destdir + name + "_sampled-%s.png"

    background = polygon(((0,0), (0,1), (1,1), (1,0)), color='grey', fill=False, aspect_ratio=1, zorder=-2, **ticks_keywords_for_faces(F_list))
    g = background + plot_projections_of_faces(additive_faces=F_list)
    g += sum(E.plot(edge_thickness=1) for E in E_list)
    g.save(fname_sampled % "2d_diagram", xmin=0, xmax=1, ymin=0, ymax=1, aspect_ratio=1,
       **ticks_keywords_for_faces(F_list))

    background = polygon(((0,0), (0,1), (1,1), (1,0)), color='grey', fill=False, aspect_ratio=1, zorder=-2, **ticks_keywords_for_faces(F_list))
    # FIXME: The ticks keywords don't seem to apply to the translation moves diagram....
    completion = DirectedMoveCompositionCompletion(fdms=[ E.functional_directed_move() for E in E_list ], show_plots=fname_sampled, plot_background=background, pts_of_discontinuity=[], show_zero_perturbation=False)
    #show(completion.plot())
    completion.complete()
    show_plot(completion.plot(), fname_sampled, tag='completion-final')

    # unsampled
    completion = DirectedMoveCompositionCompletion(covered_components=[ F.covered_component() for F in F_list ], show_plots=fname, plot_background=background, pts_of_discontinuity=[], show_zero_perturbation=False)
    completion.complete()
    show_plot(completion.plot(), fname, tag='completion-final')


###############
I, J, K = [2/19, 3/19], [6/19, 7/19], [8/19, 9/19]
F = Face([I, J, K]) # lower triangle
Fprime = Face([J, I, K]) # swapped
F_list = [F, Fprime]
E_list = symmetric_sampled_faces(F, Fprime)
plot_sampled_stuff(F_list, E_list, 'triangle')

# reflections-only version
E_list = symmetric_sampled_faces(F, Fprime, translations=False)
plot_sampled_stuff(F_list, E_list, 'triangle_reflections')

# translations-only version
E_list = symmetric_sampled_faces(F, Fprime, reflections=False)
plot_sampled_stuff(F_list, E_list, 'triangle_translations')


#################
I2, J2, K2 = [4/19, 5/19], [11/19, 12/19], [16/19, 17/19]
F2 = Face([I2, J2, K2]) # upper triangle
F2prime = Face([J2, I2, K2]) # swapped
F2_list = F_list + [F2, F2prime]  # lower and upper together (separate components)
E2_list = E_list + symmetric_sampled_faces(F2, F2prime)
plot_sampled_stuff(F2_list, E2_list, 'two_triangles')

#################
I, J, K = [3/19, 7/19], [1/19, 2/19], [4/19, 6/19]
F = Face([I, J, K]) # lower triangle
Fprime = Face([J, I, K]) # swapped
F_list = [F, Fprime]
E_list = symmetric_sampled_faces(F, Fprime)
plot_sampled_stuff(F_list, E_list, 'quadrilateral_overlapping_projections')


# #############
num_sample = 7 ;
t = [35/100 + (50-35)/100/(num_sample-1) * i for i in range(num_sample)] # delta = 0.025
x1 = []; x2=[];
for i in range(num_sample):
    x, y = var('x,y')
    eq1 = 40000*(x-0.2)^2-20000*(x-0.2)*(y-0.7)+10000*(y-0.7)^2-400*(x-0.2)+1600*(y-0.7)+1.0 == 0.0
    eq2 = y == x + t[i]
    solns = solve([eq1,eq2], x, y)
    x1.append(QQ(solns[0][0].rhs().n(30)))
    x2.append(QQ(solns[1][0].rhs().n(30)))
fdms_tau = [FunctionalDirectedMove([open_interval(x1[i],x2[i])],(1,t[i])) for i in range(num_sample)]
name = 'open_sets_of_tau'
fname = destdir + name + "-%s.png"
fname_sampled = destdir + name + "_sampled-%s.png"
x, y = var('x,y')
g = implicit_plot(40000*(x-0.2)^2-20000*(x-0.2)*(y-0.7)+10000*(y-0.7)^2-400*(x-0.2)+1600*(y-0.7)+1.0, (x, 0,1), (y,0,1),linewidth=1, linestyle=':')
for fdm in fdms_tau:
    g += fdm.plot()
show_plot(g, fname_sampled, tag='')
background = polygon(((0,0), (0,1), (1,1), (1,0)), color='grey', fill=False, aspect_ratio=1, zorder=-2)
completion_tau = DirectedMoveCompositionCompletion(fdms=fdms_tau,show_plots=fname_sampled, plot_background=background, pts_of_discontinuity=[], show_zero_perturbation=False)
completion_tau.complete()
show_plot(completion_tau.plot(), fname_sampled, tag='completion-final')

num_sample = 11 ;
r = [65/100 + (90-65)/100/(num_sample-1) * i for i in range(num_sample)]
x1 = []; x2=[];
for i in range(num_sample):
    x, y = var('x,y')
    eq1 = 40000*(x-0.2)^2-20000*(x-0.2)*(y-0.7)+10000*(y-0.7)^2-400*(x-0.2)+1600*(y-0.7)+1.0 == 0.0
    eq2 = x + y == r[i]
    solns = solve([eq1,eq2], x, y)
    x1.append(QQ(solns[0][0].rhs().n(30)))
    x2.append(QQ(solns[1][0].rhs().n(30)))
fdms_rho = [FunctionalDirectedMove([open_interval(x1[i],x2[i])],(-1,r[i])) for i in range(num_sample)]
name = 'open_sets_of_rho'
fname = destdir + name + "-%s.png"
fname_sampled = destdir + name + "_sampled-%s.png"
x, y = var('x,y')
g = implicit_plot(40000*(x-0.2)^2-20000*(x-0.2)*(y-0.7)+10000*(y-0.7)^2-400*(x-0.2)+1600*(y-0.7)+1.0, (x, 0,1), (y,0,1),linewidth=1, linestyle=':',fillcolor='red', color='red')
for fdm in fdms_rho:
    g += fdm.plot()
show_plot(g, fname_sampled, tag='')
completion_rho = DirectedMoveCompositionCompletion(fdms=fdms_rho,show_plots=fname_sampled, plot_background=background, pts_of_discontinuity=[], show_zero_perturbation=False)
completion_rho.complete()
show_plot(completion_rho.plot(), fname_sampled, tag='completion-final')

name = 'open_sets_of_moves'
fname = destdir + name + "-%s.png"
fname_sampled = destdir + name + "_sampled-%s.png"
x, y = var('x,y')
g = implicit_plot(40000*(x-0.2)^2-20000*(x-0.2)*(y-0.7)+10000*(y-0.7)^2-400*(x-0.2)+1600*(y-0.7)+1.0, (x, 0,1), (y,0,1),linewidth=1, linestyle=':',fillcolor='purple', color='purple')
fdms = fdms_tau + fdms_rho
for fdm in fdms:
    g += fdm.plot()
show_plot(g, fname_sampled, tag='')
completion = DirectedMoveCompositionCompletion(fdms=fdms,show_plots=fname_sampled, plot_background=background, pts_of_discontinuity=[], show_zero_perturbation=False)
completion.complete()
show_plot(completion.plot(), fname_sampled, tag='completion-final')
