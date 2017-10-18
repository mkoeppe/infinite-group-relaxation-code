# Make sure current directory is in path.  
# That's not true while doctesting (sage -t).
if '' not in sys.path:
    sys.path = [''] + sys.path

from igp import *
from sage.geometry.integral_points import rectangular_box_points
from sage.geometry.polyhedron.plot import cyclic_sort_vertices_2d


class PiecewisePolynomial_polyhedral(SageObject):
    """
    Define a piecewise polynomial function using pairs of (polyhedron, function).

    EXAMPLES::

        sage: square = Polyhedron(vertices = itertools.product([0, 1], repeat=2))
        sage: R.<x,y>=PolynomialRing(QQ)
        sage: h1 = PiecewisePolynomial_polyhedral([(square, x+y)])
        sage: h1
        <PiecewisePolynomial_polyhedral with 1 parts, 
         domain: A 2-dimensional polyhedron in ZZ^2 defined as the convex hull of 4 vertices: (A vertex at (0, 0), A vertex at (0, 1), A vertex at (1, 0), A vertex at (1, 1))
         function: x + y>
        sage: h1.is_continuous()
        True
        sage: h2 = PiecewisePolynomial_polyhedral([(square, -x-y)])
        sage: h1 + h2 == PiecewisePolynomial_polyhedral([(square, R(0))])
        True
        sage: h1 * h2
        <PiecewisePolynomial_polyhedral with 1 parts, 
         domain: A 2-dimensional polyhedron in ZZ^2 defined as the convex hull of 4 vertices: (A vertex at (1, 0), A vertex at (1, 1), A vertex at (0, 1), A vertex at (0, 0))
         function: -x^2 - 2*x*y - y^2>
        sage: hmax = PiecewisePolynomial_polyhedral.max(h1, h2)
        sage: hmax
        <PiecewisePolynomial_polyhedral with 1 parts, 
         domain: A 2-dimensional polyhedron in QQ^2 defined as the convex hull of 4 vertices: (A vertex at (0, 0), A vertex at (1, 1), A vertex at (0, 1), A vertex at (1, 0))
         function: x + y>
        sage: hmax.is_continuous()
        True

        sage: pairs = [(polytopes.hypercube(2), x),(polytopes.hypercube(2), -x),(polytopes.hypercube(2), y),(polytopes.hypercube(2), -y)]
        sage: h = PiecewisePolynomial_polyhedral(pairs, check_consistency=True) # compare to g = PiecewisePolynomial_polyhedral(pairs, check_consistency=False).plot()
        Traceback (most recent call last):
        ...
        ValueError: Cannot define the PiecewisePolynomial_polyhedral due to inconsistent polyhedron function pairs

        sage: hxp = PiecewisePolynomial_polyhedral([(polytopes.hypercube(2), x)])
        sage: hxn = PiecewisePolynomial_polyhedral([(polytopes.hypercube(2), -x)])
        sage: hyp = PiecewisePolynomial_polyhedral([(polytopes.hypercube(2), y)])
        sage: hyn = PiecewisePolynomial_polyhedral([(polytopes.hypercube(2), -y)])
        sage: hsublin = PiecewisePolynomial_polyhedral.max(hxp, hxn, hyp, hyn)
        sage: hsublin.limiting_slopes([0,0])
        [(0, 1), (0, -1), (1, 0), (-1, 0)]
        sage: h_restricted = hsublin.restricted_to_domain(polytopes.hypercube(2)/2)
        sage: h_restricted.plot() # not tested
        sage: len(h_restricted.pairs())
        6

        sage: hsquare = PiecewisePolynomial_polyhedral(h_restricted.pairs(), periodic_extension=True)
        sage: hsquare.plot() # not tested
        sage: hsquare.limiting_slopes([5,1])
        [(0, 1), (0, -1), (1, 0), (-1, 0)]
        sage: hsquare.which_function([5,1])
        y - 1
        sage: hsquare.which_function([5,1], Polyhedron(vertices=[(5,1),(5,3/2),(11/2,3/2)]))
        y - 1
        sage: hsquare.which_function([5,1], Polyhedron(vertices=[(5,1),(9/2,1),(9/2,3/2)]))
        -x + 5
        sage: hsquare.which_function([5,1], Polyhedron(vertices=[(5,1),(11/2,1),(11/2,3/2)]))
        x - 5
        sage: len(hsquare.pairs())
        8

        sage: hsquare_res = hsquare.restricted_to_domain(polytopes.hypercube(2)/2)
        sage: hsquare_res == h_restricted
        True
    """
    def __init__(self, polyhedron_function_pairs, periodic_extension=False, is_continuous=None, check_consistency=False):
        # polyhedron_function_pairs.sort(key=lambda (p,f):p.dim())
        for (p, f) in polyhedron_function_pairs:
            self._polynomial_ring = f.parent()
            if hasattr(f, "__call__"):
                break
        if not hasattr(f, "__call__"): # all functions are constant functions that are not callable.
            d = polyhedron_function_pairs[0][0].ambient_dim()
            self._polynomial_ring = PolynomialRing(QQ, d, 'x')
        # self._polynomial_ring = polyhedron_function_pairs[0][1].parent() # bug if the first f is rational number.
        for (i, (p, f)) in enumerate(polyhedron_function_pairs):
            if f.parent() != self._polynomial_ring:
                if f in QQ:
                    polyhedron_function_pairs[i] = (p, self._polynomial_ring(f)) # make it callable
                else:
                    raise ValueError, "Not all the functions are defined on the same PolynomialRing."
        self._dim = len(self._polynomial_ring.gens())
        self._stratification = {}
        self._periodic_extension = periodic_extension
        if not periodic_extension:
            for (p, f) in polyhedron_function_pairs:
                d = p.dim()
                if self._stratification.has_key(d):
                    self._stratification[d].add((p, f))
                else:
                    self._stratification[d] = set([(p, f)])
        else:
            #FIXME: bounding_box:  Only polytopes (compact polyhedra) are allowed.
            d = self._dim
            box = Polyhedron(vertices = itertools.product([0, 1], repeat=d))
            self._fundamental_domain = box
            for (p, f) in polyhedron_function_pairs:
                p_box = p.bounding_box(integral=True)
                p_diff = vector(0 if p_box[0][j]==p_box[1][j] else 1 for j in range(d))
                shift_min = -vector(p_box[1]) + p_diff
                shift_max = vector([1]*d) - vector(p_box[0]) - p_diff
                if check_consistency:
                    shift_min -= p_diff
                    shift_max += p_diff
                shift_vectors = rectangular_box_points(list(shift_min), list(shift_max), None)
                for v in shift_vectors:
                    shift_p = p + v # cannot take intersection here. bug example hildebrand_2_sided_discont_2_slope_1()
                    if not shift_p.intersection(box).is_empty():
                        shift_f = f(tuple(vector(self._polynomial_ring.gens())-v))
                        shift_f = self._polynomial_ring(shift_f)
                        d_p = shift_p.dim()
                        if self._stratification.has_key(d_p):
                            self._stratification[d_p].add((shift_p, shift_f))
                        else:
                            self._stratification[d_p] = set([(shift_p, shift_f)])
        self._is_piecewise_linear = True
        self._pairs = []
        # sort pairs by decreasing dim. Equiv to polyhedron_function_pairs.sort(key=lambda (p,f):p.dim())
        for (d_p, pf_set) in self._stratification.items():
            pf_list = list(pf_set)
            for i in range(len(pf_list)):
                p, f = pf_list[i]
                if f.degree() > 1:
                     self._is_piecewise_linear = False
                if check_consistency:
                    for j in range(i, len(pf_list)):
                        pj, fj = pf_list[j]
                        intersection = p.intersection(pj)
                        d = intersection.dim()
                        if d < 0:
                            continue # empty intersection
                        if d == 0:
                            z = intersection.vertices()[0]
                        else:
                            A, b = affine_map_for_affine_hull(intersection)
                            z = A * (vector(PolynomialRing(A.base_ring(),d,'z').gens())) + b
                        if f(*z) == fj(*z):
                            continue # functions agree on the intersection
                        # look for lower dimensional polyhedron that covers the intersection.
                        # should raise NotImplementedError if the intersection is partially covered.
                        found_p = False
                        for (pj, fj) in self._pairs:
                            if polyhedron_is_subset_of_another_polyhedron(intersection, pj):
                                found_p = True
                                break
                        if not found_p:
                            raise ValueError, "Cannot define the PiecewisePolynomial_polyhedral due to inconsistent polyhedron function pairs"
            self._pairs += pf_list
        if periodic_extension: #represent using cover of [0,1]^k. cannot do half open [0,1)^k
            self._stratification = {}
            for (p, f) in self._pairs:
                intersection = p.intersection(box) # not empty.
                d = intersection.dim()
                if d == p.dim(): # need this, otherwise bug hildebrand_2_sided_discont_2_slope_1(0) has two values 0 and 2*x + 3/4. 
                    if self._stratification.has_key(d):
                        self._stratification[d].add((intersection, f))
                    else:
                        self._stratification[d] = set([(intersection, f)])
            self._pairs = list(itertools.chain.from_iterable(list(v) for v in self._stratification.values()))
        self._is_continuous = is_continuous
        if is_continuous:
            d = self._pairs[-1][0].dim()
            # delete all pieces defined on lower-dimensional polyhedra.
            self._stratification =  {d: self._stratification[d]}
            self._pairs = list(self._stratification[d])
            
    # The following makes this class hashable and thus enables caching
    # of the above functions; but we must promise not to modify the
    # contents of the instance.
    def __hash__(self):
        return id(self)

    def __eq__(self, other):
        """
        Assume that self and other have the same domain (=union of the polyhedra). Return True if self == other on the domain.
        """
        if self._periodic_extension != other._periodic_extension:
            return False
        polyhedra = intersection_of_two_lists_of_polyhedra(self.polyhedra(), other.polyhedra())
        for intersection in polyhedra:
            d = intersection.dim()
            if d == 0:
                z = intersection.vertices()[0]
            else:
                A, b = affine_map_for_affine_hull(intersection)
                z = A * (vector(PolynomialRing(A.base_ring(),d,'z').gens())) + b
            for (p_self, f_self) in self.pairs():
                if polyhedron_is_subset_of_another_polyhedron(intersection, p_self):
                    break
            for (p_other, f_other) in other.pairs():
                if polyhedron_is_subset_of_another_polyhedron(intersection, p_other):
                    break
            if f_self(*z) != f_other(*z):
                return False
        return True

    def is_continuous(self):
        """
        return if the function is continuous.
        """
        if not self._is_continuous is None:
            return self._is_continuous
        polyhedra = intersection_of_two_lists_of_polyhedra(self.polyhedra(), self.polyhedra())
        for intersection in polyhedra:
            d = intersection.dim()
            if d == 0:
                z = intersection.vertices()[0]
            else:
                A, b = affine_map_for_affine_hull(intersection)
                z = A * (vector(PolynomialRing(A.base_ring(),d,'z').gens())) + b
            poly = None
            for (p, f) in self.pairs():
                if polyhedron_is_subset_of_another_polyhedron(intersection, p):
                    poly_f = f(*z)
                    if poly is None:
                        poly = poly_f
                    if poly_f != poly:
                        self._is_continuous = False
                        return False        
        self._is_continuous = True
        return True

    def pairs(self):
        return self._pairs

    def polyhedra(self):
        return [p for (p, f) in self.pairs()]
    
    def functions(self):
        return [f for (p, f) in self.pairs()]

    def dim(self):
        return self._dim

    def __add__(self, other):
        """
        Add self and another piecewise function.
        The sum is a function defined on the intersetion of the domain of self and the domain of other.
        """
        if self._periodic_extension != other._periodic_extension:
            raise NotImplementedError
        if self.is_continuous() and other.is_continuous():
            is_continuous = True
        else:
            is_continuous = None
        polyhedra = intersection_of_two_lists_of_polyhedra(self.polyhedra(), other.polyhedra())
        pairs = []
        for intersection in polyhedra:
            for (p_self, f_self) in self.pairs():
                if polyhedron_is_subset_of_another_polyhedron(intersection, p_self):
                    break
            for (p_other, f_other) in other.pairs():
                if polyhedron_is_subset_of_another_polyhedron(intersection, p_other):
                    break
            pairs.append((intersection, f_self + f_other))
        result = PiecewisePolynomial_polyhedral(pairs, is_continuous=is_continuous, check_consistency=False)
        # We avoided transaltions and checks in construction of PiecewisePolynomial_polyhedral by setting periodic_extension=False.
        # Set it back to self._periodic_extension now.
        result._periodic_extension = self._periodic_extension 
        return result

    def __neg__(self):
        result = PiecewisePolynomial_polyhedral([(p, -f) for (p, f) in self.pairs()], is_continuous=self._is_continuous, check_consistency=False)
        result._periodic_extension = self._periodic_extension
        return result

    def __mul__(self, other):
        """
        Multiply self by a scalar or another piecewise function.
        The product is a function defined on the intersetion of the domain of self and the domain of other.
        """
        if self._periodic_extension != other._periodic_extension:
            raise NotImplementedError
        if self.is_continuous() and other.is_continuous():
            is_continuous = True
        else:
            is_continuous = None
        if not isinstance(other, PiecewisePolynomial_polyhedral):
            # assume scalar multiplication
            result = PiecewisePolynomial_polyhedral([(p, other*f) for (p, f) in self.pairs()], is_continuous=is_continuous, check_consistency=False)
            result._periodic_extension = self._periodic_extension
            return result
        else:
            polyhedra = intersection_of_two_lists_of_polyhedra(self.polyhedra(), other.polyhedra())
            pairs = []
            for intersection in polyhedra:
                for (p_self, f_self) in self.pairs():
                    if polyhedron_is_subset_of_another_polyhedron(intersection, p_self):
                        break
                for (p_other, f_other) in other.pairs():
                    if polyhedron_is_subset_of_another_polyhedron(intersection, p_other):
                        break
                pairs.append((intersection, f_self * f_other))
            result = PiecewisePolynomial_polyhedral(pairs, is_continuous=is_continuous, check_consistency=False)
            result._periodic_extension = self._periodic_extension
            return result
        
    __rmul__ = __mul__

    def __div__(self, other):
        return self * (1 / other)
    
    def __sub__(self, other):
        return self + (-other)

    def __repr__(self):
        rep = "<PiecewisePolynomial_polyhedral with %s parts, " % len(self.pairs())
        for (p, f) in self.pairs():
            rep += "\n domain: " + repr(p) + ": " + repr(p.Vrepresentation())
            rep += "\n function: " + repr(f)
        rep += ">"
        return rep

    def sage_input(self):
        # Temporary. Output is a string.
        rep = "PiecewisePolynomial_polyhedral(["
        for (p, f) in self.pairs():
            rep += "(%s, %s), " %  (repr(sage_input(p)), repr(f))
        rep += "], periodic_extension=%s, is_continuous=%s, check_consistency=False)" % (self._periodic_extension, self._is_continuous)
        return rep

    def __call__(self, x, *arg):
        if arg: # to allow the call h(1,2,3) in addition to h(vector([1,2,3]) and h([1,2,3]).
            x = vector([x]+list(arg))
        if self._periodic_extension:
            x = mod_Zk(x)
        for (p, f) in self.pairs():
            if x in p:
                return f(tuple(x))
        raise ValueError, "Point x is outside the domain of the function."

    def limit(self, x, polyhedron=None):
        """
        Return the limit of self at x approchaing from the relative interior of polyhedron,
        where the input polyhedron is contained in the domain of some piece of the function.
        if polyhedron=None, then return the function value at x.
        """
        f = self.which_function(x, polyhedron)
        if (not polyhedron is None) and (not x in polyhedron):
            raise ValueError, "The given point x is not contained in the polyhedron."
        return f(tuple(x))

    def which_function(self, x=None, polyhedron=None):
        """
        Return the function of the (first) piece whose domain containts x, if polyhedron=None;
        return the function of the (first) piece whose domain containts polyhedron, otherwise.
        """
        if (x is not None) and (polyhedron is not None) and (not x in polyhedron):
            raise ValueError, "Polyhedron does not contain the point x."
        if not self._periodic_extension:
            if polyhedron is None:
                for (p, f) in self.pairs():
                    if x in p:
                        return f
                raise ValueError, "The function is not defined on the point x."
            else:
                for (p, f) in self.pairs():
                    if polyhedron_is_subset_of_another_polyhedron(polyhedron, p):
                        return f
                raise ValueError, "The given polyhedron is not contained in any of the polyhedra where the function is defined."
        else:
            x0 = list(mod_Zk(x))
            z = vector(self._polynomial_ring.gens()) - vector(x) + vector(x0)
            x_translate = [x0]
            # compoute the translations of x by Zk.
            for i in range(self.dim()):
                if x0[i] == 0:
                    x_translate += [[xt[j] if j != i else 1 for j in range(self.dim())] for xt in x_translate]
            shifts = [vector(x) - vector(xi) for xi in x_translate]           
            if polyhedron is None:
                for (p, f) in self.pairs():
                    if x0 in p:
                        return self._polynomial_ring(f(tuple(z)))
                raise ValueError, "The function is not defined on the point x."
            else:
                for shift in shifts:
                    polyhedron_shift = (polyhedron - shift).intersection(self._fundamental_domain)
                    if polyhedron_shift.dim() == polyhedron.dim(): #tricky!
                        break
                z = vector(self._polynomial_ring.gens()) - shift
                for (p, f) in self.pairs():
                    if polyhedron_is_subset_of_another_polyhedron(polyhedron_shift, p):
                        return self._polynomial_ring(f(tuple(z)))
                raise ValueError, "The given polyhedron is not contained in any of the polyhedra where the function is defined."

    def restricted_to_domain(self, domain):
        """
        Return a PiecewisePolynomial_polyhedral which is self restricted to domain, where domain is a given polyhedron.
        """
        if self._is_continuous:
            is_continuous = True
        else:
            is_continuous = None
        if self._periodic_extension:
            d = self._dim
            selfpairs = []
            #FIXME: bounding_box:  Only polytopes (compact polyhedra) are allowed.
            domain_box = domain.bounding_box(integral=True)
            domain_diff = vector(0 if domain_box[0][j]==domain_box[1][j] else 1 for j in range(d))
            shift_min = -vector([1]*d) + vector(domain_box[0]) + domain_diff
            shift_max = vector(domain_box[1]) - domain_diff
            shift_vectors = rectangular_box_points(list(shift_min), list(shift_max), None)
            for v in shift_vectors:
                for (p, f) in self.pairs():
                    shift_p = p + v #tricky. cannot record intersection only because it may reduce dim.
                    if not shift_p.intersection(domain).is_empty():
                        shift_f = self._polynomial_ring(f(tuple(vector(self._polynomial_ring.gens())-v)))
                        selfpairs.append((shift_p, shift_f))
            selfpairs.sort(key=lambda (p,f):p.dim())
        else:
            selfpairs = self.pairs()
        pairs = []
        for (p, f) in selfpairs:
            intersection = domain.intersection(p)
            if intersection.is_empty():
                continue
            if intersection.dim() == p.dim():
                pairs.append((intersection, f))
            elif all(pp != intersection for (pp, ff) in pairs):
                pairs.append((intersection, f))
        return PiecewisePolynomial_polyhedral(pairs, periodic_extension=False, is_continuous=is_continuous, check_consistency=False)

    def max(self, other, *arg):
        """
        EXAMPLES::

            sage: R.<x,y>=PolynomialRing(QQ)
            sage: hp = PiecewisePolynomial_polyhedral([(polytopes.hypercube(2), x+y)])
            sage: hn = PiecewisePolynomial_polyhedral([(polytopes.hypercube(2), -x-y)])
            sage: PiecewisePolynomial_polyhedral.max(hp, hn)
            <PiecewisePolynomial_polyhedral with 2 parts, 
             domain: A 2-dimensional polyhedron in QQ^2 defined as the convex hull of 3 vertices: (A vertex at (1, -1), A vertex at (-1, 1), A vertex at (1, 1))
             function: x + y
             domain: A 2-dimensional polyhedron in QQ^2 defined as the convex hull of 3 vertices: (A vertex at (-1, 1), A vertex at (1, -1), A vertex at (-1, -1))
             function: -x - y>
        """
        if not (self._is_piecewise_linear and other._is_piecewise_linear):
            raise NotImplementedError, "Not implemented for non-linear PiecewisePolynomial_polyhedral functions."
        if self._periodic_extension != other._periodic_extension:
            raise NotImplementedError
        if self.is_continuous() and other.is_continuous():
            is_continuous = True
        else:
            is_continuous = None
        polyhedra = intersection_of_two_lists_of_polyhedra(self.polyhedra(), other.polyhedra())
        pairs = []
        for intersection in polyhedra:
            for (p_self, f_self) in self.pairs():
                if polyhedron_is_subset_of_another_polyhedron(intersection, p_self):
                    break
            for (p_other, f_other) in other.pairs():
                if polyhedron_is_subset_of_another_polyhedron(intersection, p_other):
                    break
            f_diff = f_self - f_other
            half_space_pos = Polyhedron(ieqs=[[f_diff.constant_coefficient()]+[f_diff.monomial_coefficient(xi) for xi in self._polynomial_ring.gens()]])
            half_space_neg = Polyhedron(ieqs=[[-f_diff.constant_coefficient()]+[-f_diff.monomial_coefficient(xi) for xi in self._polynomial_ring.gens()]])
            p_max_self = intersection.intersection(half_space_pos)
            p_max_other = intersection.intersection(half_space_neg)
            if not p_max_self.is_empty():
                pairs.append((p_max_self, f_self))
            if not p_max_other.is_empty():
                pairs.append((p_max_other, f_other))
        result = PiecewisePolynomial_polyhedral(pairs, is_continuous=is_continuous, check_consistency=False)
        result._periodic_extension = self._periodic_extension
        if not arg:
            return result
        return result.max(arg[0], *arg[1::])
            

    def min(self, other, *arg):
        """
        EXAMPLES::

            sage: R.<x,y>=PolynomialRing(QQ)
            sage: hp = PiecewisePolynomial_polyhedral([(polytopes.hypercube(2), x+y)])
            sage: hn = PiecewisePolynomial_polyhedral([(polytopes.hypercube(2), -x-y)])
            sage: PiecewisePolynomial_polyhedral.min(hp, hn)
            <PiecewisePolynomial_polyhedral with 2 parts, 
             domain: A 2-dimensional polyhedron in QQ^2 defined as the convex hull of 3 vertices: (A vertex at (-1, 1), A vertex at (1, -1), A vertex at (-1, -1))
             function: x + y
             domain: A 2-dimensional polyhedron in QQ^2 defined as the convex hull of 3 vertices: (A vertex at (1, -1), A vertex at (-1, 1), A vertex at (1, 1))
             function: -x - y>
        """
        if not (self._is_piecewise_linear and other._is_piecewise_linear):
            raise NotImplementedError, "Not implemented for non-linear PiecewisePolynomial_polyhedral functions."
        if self._periodic_extension != other._periodic_extension:
            raise NotImplementedError
        if self.is_continuous() and other.is_continuous():
            is_continuous = True
        else:
            is_continuous = None
        polyhedra = intersection_of_two_lists_of_polyhedra(self.polyhedra(), other.polyhedra())
        pairs = []
        for intersection in polyhedra:
            for (p_self, f_self) in self.pairs():
                if polyhedron_is_subset_of_another_polyhedron(intersection, p_self):
                    break
            for (p_other, f_other) in other.pairs():
                if polyhedron_is_subset_of_another_polyhedron(intersection, p_other):
                    break
            f_diff = f_self - f_other
            half_space_pos = Polyhedron(ieqs=[[f_diff.constant_coefficient()]+[f_diff.monomial_coefficient(xi) for xi in self._polynomial_ring.gens()]])
            half_space_neg = Polyhedron(ieqs=[[-f_diff.constant_coefficient()]+[-f_diff.monomial_coefficient(xi) for xi in self._polynomial_ring.gens()]])
            p_min_self = intersection.intersection(half_space_neg)
            p_min_other = intersection.intersection(half_space_pos)
            if not p_min_self.is_empty():
                pairs.append((p_min_self, f_self))
            if not p_min_other.is_empty():
                pairs.append((p_min_other, f_other))
        result = PiecewisePolynomial_polyhedral(pairs, is_continuous=is_continuous, check_consistency=False)
        result._periodic_extension = self._periodic_extension
        if not arg:
            return result
        return result.min(arg[0], *arg[1::])
            

    def plot(self, domain=None, opacity=0.5):
        """     
        EXAMPLES::
        
            sage: logging.disable(logging.INFO)
            sage: fn = hildebrand_discont_3_slope_1()
            sage: h = piecewise_polynomial_polyhedral_from_fast_piecewise(fn)
            sage: h_diag_strip = h.affine_linear_embedding(matrix([(1,1)]))
            sage: h_diag_strip.plot() #not tested

            sage: M = matrix([[0,1/4,1/2],[1/4,1/2,3/4],[1/2,3/4,1]])  # q=3
            sage: h = PiecewisePolynomial_polyhedral.from_values_on_group_triangulation(M) # grid=(1/qZ)^2
            sage: h.plot() #not tested
        """
        if self.dim() != 2 or not self._is_piecewise_linear:
            raise NotImplementedError, "plot is not implemented."
        if domain is None:
            pwl = self
        else:
            pwl = self.restricted_to_domain(domain)
        slopes = uniq([tuple(f.monomial_coefficient(xi) for xi in pwl._polynomial_ring.gens()) for f in pwl.functions()])
        slope_color = {}
        for i in range(len(slopes)):
            slope_color[slopes[i]] = rainbow(len(slopes))[i]
        g = polygon3d([])
        for (p, f) in pwl.pairs()[::-1]:
            if not p.is_compact():
                raise ValueError, "The function has unbounded domain. Please provide the domain for plotting.\nFor example, domain=polytopes.hypercube(%s)" % self.dim()
            s = tuple(f.monomial_coefficient(xi) for xi in pwl._polynomial_ring.gens())
            color = slope_color[s]
            p_vertices = cyclic_sort_vertices_2d(p.vertices())
            vertices = [list(v)+[f(list(v))] for v in p_vertices]
            if p.dim() == 2:
                face = polygon3d(vertices, color=color)
                # workaround. polygon plot forgets about keyword argument opacity. 
                face._extra_kwds['opacity'] = opacity
            elif p.dim() == 1:
                face = line3d(vertices, color=color)
                #face._extra_kwds['opacity'] = opacity
            else:
                face = point3d(vertices, color='black')
            g += face
        show(g, viewer='threejs')
        # return g

    def plot_projection(self, domain=None, group_triangulation=False, show_values_on_vertices=False):
        """     
        EXAMPLES::
        
            sage: logging.disable(logging.INFO)
            sage: fn = hildebrand_discont_3_slope_1()
            sage: h = piecewise_polynomial_polyhedral_from_fast_piecewise(fn)
            sage: h_diag_strip = h.affine_linear_embedding(matrix([(1,1)]))
            sage: g = h_diag_strip.plot_projection()

            sage: M = matrix([[0,1/4,1/2],[1/4,1/2,3/4],[1/2,3/4,1]])  # q=3
            sage: h = PiecewisePolynomial_polyhedral.from_values_on_group_triangulation(M) # grid=(1/qZ)^2
            sage: g = h.plot_projection(group_triangulation=True)

            sage: PR.<x,y>=PolynomialRing(QQ)
            sage: pairs = [(polytopes.hypercube(2)-vector([1,0]), 0), (polytopes.hypercube(2)+vector([1,0]), 0), (Polyhedron(vertices=[(0,1),(0,-1)]), x+y+1), (Polyhedron(vertices=[(0,0)]), 0)]
            sage: h = PiecewisePolynomial_polyhedral(pairs)
            sage: g = h.plot_projection()
            sage: g.show(xmin=-0.1, xmax=0.1, ymin=-0.1, ymax=0.1) # not tested

            sage: PR.<x,y> = PolynomialRing(QQ)
            sage: h = PiecewisePolynomial_polyhedral([(Polyhedron(vertices=[(0, 0), (1, 1), (1, -1)]), x), (Polyhedron(vertices=[(0, 0), (-1, 1), (-1, -1)]), -x), (Polyhedron(vertices=[(0, 0), (1, 1), (-1, 1)]), y), (Polyhedron(vertices=[(0, 0), (1, -1), (-1, -1)]), -y)])
            sage: g = h.plot_projection(show_values_on_vertices=True)

            sage: pairs = [(Polyhedron(vertices=[(0,0), (0,1), (1,0)]), 0), (Polyhedron(vertices=[(0,0), (0,1)]), 1), (Polyhedron(vertices=[(0,1), (1,0)]), 1), (Polyhedron(vertices=[(0,0), (1,0)]), 1)]
            sage: h = PiecewisePolynomial_polyhedral(pairs)
            sage: g = h.plot_projection()
        """
        if self.dim() != 2 or not self._is_piecewise_linear:
            raise NotImplementedError, "plot is not implemented."
        if domain is None:
            pwl = self
        else:
            pwl = self.restricted_to_domain(domain)
        slopes = uniq([tuple(f.monomial_coefficient(xi) for xi in pwl._polynomial_ring.gens()) for f in pwl.functions()])
        slope_color = {}
        for i in range(len(slopes)):
            slope_color[slopes[i]] = rainbow(len(slopes))[i]
        g = Graphics()
        n = len(pwl.pairs())  #pairs are ordered according to the decreasing order on the dim of polyhedral domains.
        colors_on_domains = [None] * n
        for i in range(n-1, -1, -1):
            (p, f) = pwl.pairs()[i]
            if not p.is_compact():
                raise ValueError, "The function has unbounded domain. Please provide the domain for plotting."
            s = tuple(f.monomial_coefficient(xi) for xi in pwl._polynomial_ring.gens())
            color = slope_color[s]
            if p.dim() == 2:
                g += p.plot(fill=color, wireframe=False, alpha=0.5)
                colors_on_domains[i] = color
            elif p.dim() == 1:
                v0 = vector(p.vertices()[0])
                v1 = vector(p.vertices()[1]) #p is bounded, so dim-1 p is a line segment.
                l = v1-v0
                l_orth = vector([-l[1]/RR(l.norm())/60, l[0]/RR(l.norm())/60])
                L = Polyhedron(vertices = [v0 + l_orth, v0 - l_orth], lines = [l])
                discontinuity = False
                for j in range(n-1, i, -1):
                    (pj, fj) = pwl.pairs()[j]
                    if (v0 in pj) and (v1 in pj):
                        if f(tuple(v0)) == fj(tuple(v0)) and f(tuple(v1)) == fj(tuple(v1)):
                            color = colors_on_domains[j]
                        else:
                            discontinuity = True
                            stripe =  pj.intersection(L)
                            g += stripe.plot(fill='white', wireframe=False, alpha=1)
                if discontinuity:
                    g += line([v0, v1], color=color, thickness=2, zorder=2)
                colors_on_domains[i] = color
            else: #p.dim() == 0"
                v = vector(p.vertices()[0])
                # C is a disk of radius 1/60 centered at v.
                C = v + Polyhedron(vertices = [(RR(sin(pi*k/36))/60, RR(cos(pi*k/36))/60) for k in range(73)])
                discontinuity = False
                for j in range(n-1, i, -1):
                    (pj, fj) = pwl.pairs()[j]
                    if (v in pj):
                        sector = pj.intersection(C)
                        if f(tuple(v)) == fj(tuple(v)):
                            color = colors_on_domains[j]
                        else:
                            discontinuity = True
                            color = 'white'
                        if sector.dim() == 2:
                            g += sector.plot(fill='white', wireframe=False, alpha=1, zorder=3)
                            g += sector.plot(fill=color, wireframe=False, alpha=0.5, zorder=3)
                        else: # sector.dim() == 1:
                            g += line(sector.vertices_list(), color=color, thickness=2, zorder=4)
                if discontinuity:
                    g += point(v, color='black', size=10, zorder=5)
                colors_on_domains[i] = 'black'
        if group_triangulation:
            q = self._q
            for i in range(q+1):
                x = QQ(i)/q
                g += line([(x,0), (x,1)], color='black', zorder=6)
                g += line([(0,x), (1,x)], color='black', zorder=6)
                g += line([(0,x), (x,0)], color='black', zorder=6)
                g += line([(x,1), (1,x)], color='black', zorder=6)
            for i in range(q+1):
                for j in range(q+1):
                    x = QQ(i)/q
                    y = QQ(j)/q
                    g += text(pwl(x,y), (x,y), fontsize=16, color='black', zorder=6, background_color='white')
        elif show_values_on_vertices and not (self.is_continuous() is False) :
            for (p, f) in self.pairs():
                for v in p.vertices_list():
                    g += text(pwl(v), v, fontsize=16, color='black', zorder=6, background_color='white')         
        return g

    def limiting_slopes(self, x=None):
        """
        Return the gradients of the affine functions on the full-dim polyhedron whose closure contains x.
        """
        if not self._is_piecewise_linear:
            raise NotImplementedError, "Not implemented for non-linear PiecewisePolynomial_polyhedral functions."
        if x is None:
            x = [0] * self.dim()
        if self._periodic_extension:
            x0 = list(mod_Zk(x))
            x_translate = [x0]
            # compoute the translations of x by Zk.
            for i in range(self.dim()):
                if x0[i] == 0:
                    x_translate += [[xt[j] if j != i else 1 for j in range(self.dim())] for xt in x_translate]
        else:
            x_translate = [x]
        slopes = set([])
        for xt in x_translate:
            for (p, f) in self.pairs():
                if xt in p:
                    s = tuple(f.monomial_coefficient(xi) for xi in self._polynomial_ring.gens())
                    slopes.add(s)
        return list(slopes)

    def translation(self, t):
        """
        Return the translated PiecewisePolynomial_polyhedral function x -> self(x+t).
        """
        v = vector(t)
        pairs = [(p.translation(v), self._polynomial_ring(f(tuple(vector(self._polynomial_ring.gens())-v)))) for (p, f) in self.pairs()]
        return PiecewisePolynomial_polyhedral(pairs, periodic_extension=self._periodic_extension, is_continuous=self._is_continuous, check_consistency=False)

    def affine_linear_embedding(self, A, b=None):
        """
        Given full row rank matrix A and vector b (default b = 0). 
        Return the composition PiecewisePolynomial_polyhedral function x -> self(A*x+b).
        
        EXAMPLES::
        
            sage: logging.disable(logging.INFO)
            sage: fn = hildebrand_discont_3_slope_1()
            sage: h = piecewise_polynomial_polyhedral_from_fast_piecewise(fn)
            sage: h_vert_strip = h.affine_linear_embedding(matrix([(1,0)]))
            sage: h_diag_strip = h.affine_linear_embedding(matrix([(1,1)]))
            sage: h_vert_strip.plot(polytopes.hypercube(2)) # not tested
            sage: h_diag_strip.plot() # not tested
        """
        m, n = A.dimensions()
        assert m == self.dim()
        PR = PolynomialRing(QQ, n, 'x')
        x = vector(PR.gens())
        if b is None:
            b = vector(QQ, m)
        if self._periodic_extension:
            # TODO: Read Equiv-III, fundamental domain via affine transformation.
            # Temporary code, assume [0,1]^n to be the fundamental domain of the resulting function.
            vertices = [A * vector(v) + b for v in itertools.product([0, 1], repeat=n)]
            domain = Polyhedron(vertices=vertices)
            selfpairs = self.restricted_to_domain(domain).pairs()
        else:
            selfpairs = self.pairs()
        pairs = []
        for (p, f) in selfpairs:
            vq = [A.solve_right(vector(v) - b) for v in p.vertices()]
            rq = [A.solve_right(vector(v)) for v in p.rays()]
            lq = [A.solve_right(vector(v)) for v in p.lines()] + [vector(v) for v in A.right_kernel_matrix()]
            q = Polyhedron(vertices=vq, rays=rq, lines=lq)
            g = PR(f(tuple(A * x + b)))  # Was a bug, type of g can be rational instead of PR.
            pairs.append((q, g))
        result = PiecewisePolynomial_polyhedral(pairs, periodic_extension=False, is_continuous=self._is_continuous, check_consistency=False)
        if self._periodic_extension: # FIXME.
            result = result.restricted_to_domain(Polyhedron(vertices = itertools.product([0, 1], repeat=n)))
            result._periodic_extension = True
        return result

    @classmethod
    def from_values_on_group_triangulation(cls, M):
        """
        EXAMPLES::

            sage: M = matrix([[0,1/4,1/2],[1/4,1/2,3/4],[1/2,3/4,1]])  # q=3
            sage: h = PiecewisePolynomial_polyhedral.from_values_on_group_triangulation(M) # grid=(1/qZ)^2
        """
        q = sage.rings.integer.Integer(M.dimensions()[0])
        PR = PolynomialRing(QQ, 2, 'x')
        pairs = []
        # little lower triangles 
        for i in range(q):
            for j in range(q):
                A = matrix([(i, j, q), (i, (j+1), q), ((i+1), j, q)])
                b = vector([M[i,j] * q, M[i,(j+1) % q] * q, M[(i+1) % q, j] * q])
                (cx, cy, c) = A.solve_right(b)
                p = Polyhedron(vertices = [(i/q, j/q), (i/q, (j+1)/q), ((i+1)/q, j/q)])
                f = cx * PR.gens()[0] + cy * PR.gens()[1] + c
                pairs.append((p,f))
        # little upper triangles
        for i in range(1,q+1):
            for j in range(1,q+1):
                A = matrix([(i, j, q), (i, (j-1), q), ((i-1), j, q)])
                b = vector([M[i % q, j % q] * q, M[i % q, j-1] * q, M[i-1, j % q] * q])
                (cx, cy, c) = A.solve_right(b)
                p = Polyhedron(vertices = [(i/q, j/q), (i/q, (j-1)/q), ((i-1)/q, j/q)])
                f = cx * PR.gens()[0] + cy * PR.gens()[1] + c
                pairs.append((p,f))
        result = PiecewisePolynomial_polyhedral(pairs, is_continuous=True) #, check_consistency=False)
        result._periodic_extension = True
        result._q = q
        return result

    def is_non_negative(self):
        """
        Return True if self >= 0 everywhere.
        """
        if not self._is_piecewise_linear:
            raise NotImplementedError, "Not implemented for non-linear PiecewisePolynomial_polyhedral functions."
        for (p, f) in self.pairs():
            if not (all(f(v) >= 0 for v in p.vertices_list()) and \
                    all(f(r) >= f.constant_coefficient() for r in p.rays_list()) and \
                    all(f(l) == f.constant_coefficient() for l in p.lines_list())):
                return False
        return True

    def preimage(self, value):
        """
        Return closure of the preimage, as a list of polyhedra, of the given value under the map self.

        EXAMPLES::

            sage: logging.disable(logging.INFO)
            sage: fn = gmic()
            sage: h = piecewise_polynomial_polyhedral_from_fast_piecewise(fn)
            sage: delta = subadditivity_slack_delta(h)
            sage: preimages = delta.preimage(5/4)
            sage: len(preimages)
            1
            sage: preimages[0].vertices()
            (A vertex at (4/5, 4/5), A vertex at (4/5, 1/5), A vertex at (1/5, 4/5))
            sage: additive_domain= delta.preimage(0)
            sage: len(additive_domain)
            6
            sage: g = sum(p.plot() for p in additive_domain) # not tested

            sage: PR.<x,y>=PolynomialRing(QQ)
            sage: pairs = [(polytopes.hypercube(2)-vector([1,0]), 0), (polytopes.hypercube(2)+vector([1,0]), 0), (Polyhedron(vertices=[(0,1),(0,-1)]), x+y+1), (Polyhedron(vertices=[(0,0)]), 0)]
            sage: h = PiecewisePolynomial_polyhedral(pairs)
            sage: h.preimage(1)
            []

            sage: pairs = [(Polyhedron(vertices=[(0,0), (0,1), (1,0)]), 0), (Polyhedron(vertices=[(0,0), (0,1)]), 1), (Polyhedron(vertices=[(0,1), (1,0)]), 1), (Polyhedron(vertices=[(0,0), (1,0)]), 1)]
            sage: h = PiecewisePolynomial_polyhedral(pairs)
            sage: len(h.preimage(0))
            1
        """
        if not self._is_piecewise_linear:
            raise NotImplementedError, "Not implemented for non-linear PiecewisePolynomial_polyhedral functions."
        result = []
        for i in range(len(self.pairs())-1, -1, -1):
            (p, f) = self.pairs()[i]
            d = p.dim()
            H = Polyhedron(eqns=[[f.constant_coefficient()-value]+[f.monomial_coefficient(xi) for xi in self._polynomial_ring.gens()]])
            intersection = p.intersection(H)
            if intersection.is_empty():
                continue
            in_preimage = True
            for (pj, fj) in self.pairs()[:i]:
                if pj.dim() < d and polyhedron_is_subset_of_another_polyhedron(intersection, pj):
                    in_preimage = False
                    break
            for pj in result:
                if polyhedron_is_subset_of_another_polyhedron(intersection, pj):
                    in_preimage = False
                    break
            if in_preimage:
                result.append(intersection)
        preimages = []  # eliminate lower dim polyhedra that are contained in others.
        for i in range(len(result)):
            p = result[i]
            if all(polyhedron_is_subset_of_another_polyhedron(p, result[j]) is False for j in range(i+1,len(result))):
                preimages.append(p)
        return preimages

def mod_Zk(x):
    return vector(xi - floor(xi) for xi in x)

def div_Zk(x):
    return vector(floor(xi) for xi in x)

def intersection_of_two_lists_of_polyhedra(polyhedra_1, polyhedra_2):
    """
    pairwise intersections
    """
    intersections = {}
    for p1 in polyhedra_1:
        for p2 in polyhedra_2:
            p = p1.intersection(p2)
            d = p.dim()
            if d >= 0:
                if intersections.has_key(d):
                    intersections[d].add(p)
                else:
                    intersections[d] = set([p])
    polyhedra = []
    for ps in intersections.values():
        polyhedra += list(ps)
    return polyhedra

def affine_map_for_affine_hull(p):
        """
        Return the an affine map x -> A*x+b that maps the affine space of p to the ambient space of p.
        The affine space of p (in the ambient space) is equal to {A(x) + b for x in the projected space}.
        This is adapted from sage.geometry.polyhedron.base.affine_hull. 
        Note that the meanings of A, b and v0  are modified. We also handle the unbounded case.
        """
        # handle trivial full-dimensional case
        if p.ambient_dim() == p.dim():
            return matrix(p.base_ring(), p.dim(), p.dim(), p.base_ring().one()).transpose(), p.ambient_space().zero()

        # translate 0th vertex to the origin
        Q = p.translation(-vector(p.vertices()[0]))
        # workaround of :trac:`24047`. 
        for v in Q.vertices():
            if v.vector() == Q.ambient_space().zero():
                break
        M = matrix([list(v) for v in Q.Vrepresentation()])
        A = M.gram_schmidt(orthonormal=False)[0]
        return A.transpose(), vector(A.base_ring(), p.vertices()[0])
        # #W =[list(w) for w in matrix(Q.vertices_list()).row_space().basis()]
        # # choose as an affine basis the neighbors of the origin vertex in Q
        # W = [list(w) for w in itertools.islice(v.neighbors(), p.dim())]
        # # handle the unbounded case.
        # for r in p.rays():
        #     if len(W) < p.dim():
        #         W.append(list(r))
        # for l in p.lines():
        #     if len(W) < p.dim():
        #         W.append(list(l))
        # M = matrix(p.base_ring(), p.dim(), p.ambient_dim(), W)
        # A = M.gram_schmidt(orthonormal=False)[0]
        # return A.transpose(), vector(A.base_ring(), p.vertices()[0])

def polyhedron_is_subset_of_another_polyhedron(pa, pb):
    """
    Return if polyhedron a is contained in polyhedron b.
    """
    return (pb.dim() >= pa.dim()) and \
        all(v in pb for v in pa.vertices()) and \
        all(r in (pb - pb.center()) for r in pa.rays()) and \
        all(l in (pb - pb.center()) for l in pa.lines())

def sublinear_function_from_slopes(slopes):
    """
    Return a sublinear PiecewisePolynomial_polyhedral function whose gradients at the orgin are give by the parameter slopes.

    EXAMPLES::

        sage: sublin_function = sublinear_function_from_slopes([(0, 1), (0, -1), (1, 0), (-1, 0)])
        sage: sublin_function(10,10)
        10
        sage: sublin_function.plot(domain=polytopes.hypercube(2)) # not tested
    """
    d = len(slopes[0])
    PR = PolynomialRing(QQ, d, 'x')
    linear_functions = []
    p = sage.geometry.polyhedron.parent.Polyhedra(QQ,d).universe()
    for s in slopes:
        f = sum(PR.gens()[i] * s[i] for i in range(d))
        linear_functions.append(PiecewisePolynomial_polyhedral([(p,f)],is_continuous=True, check_consistency=False))
    sublin_function = PiecewisePolynomial_polyhedral.max(*linear_functions)
    return sublin_function

    
def subadditive_function_from_sublinear_function(sublin_function):
    """
    Trivial fill-in? Return a Zk-periodic PiecewisePolynomial_polyhedral function.

    EXAMPLES::

        sage: sublin_function = sublinear_function_from_slopes([(0, 1), (0, -1), (1, 0), (-1, 0)])
        sage: subadd_function = subadditive_function_from_sublinear_function(sublin_function)
        sage: subadd_function(10,10) == subadd_function(0,0)
        True
    """
    subadd = PiecewisePolynomial_polyhedral.min(*(sublin_function.translation(t) \
                                                  for t in itertools.product([0, 1], repeat=sublin_function.dim())))
    subadd_function = subadd.restricted_to_domain(Polyhedron(vertices = itertools.product([0, 1], repeat=sublin_function.dim())))
    subadd_function._periodic_extension = True
    return subadd_function


def subadditive_function_from_slopes(slopes):
    """
    Return a Zk-periodic subadditive PiecewisePolynomial_polyhedral function 
    whose gradients at the orgin are give by the parameter slopes.

    EXAMPLES::

        sage: subadd_function = subadditive_function_from_slopes([(0, 1), (0, -1), (1, 0), (-1, 0)])
        sage: subadd_function(10,10)
        0
    """
    sublin_function = sublinear_function_from_slopes(slopes)
    subadd_function = subadditive_function_from_sublinear_function(sublin_function)
    return subadd_function
    
def piecewise_polynomial_polyhedral_from_fast_piecewise(fn):
    """
    Convert a FastPiecewise type function fn to a PiecewisePolynomial_polyhedral type one.

    EXAMPLES::
        
        sage: logging.disable(logging.INFO)
        sage: fn = gmic()
        sage: h = piecewise_polynomial_polyhedral_from_fast_piecewise(fn)
    """
    PR.<x> = PolynomialRing(QQ,1)
    bkpts = fn.end_points()
    limits = fn.limits_at_end_points()
    pairs = []
    for i in range(len(bkpts)):
        if not limits[i][0] == limits[i][1] == limits[i][-1]:
            p = Polyhedron(vertices=[[bkpts[i]]])
            f = fn.which_function(bkpts[i])(x)
            pairs.append((p,f))
    for i in range(len(bkpts)-1):
        p = Polyhedron(vertices=[[bkpts[i]],[bkpts[i+1]]])
        f = PR(fn.which_function_on_interval([bkpts[i], bkpts[i+1]])(x))
        pairs.append((p,f))
    return PiecewisePolynomial_polyhedral(pairs, periodic_extension=True, is_continuous=fn.is_continuous(), check_consistency=True)

def subadditivity_slack_delta(h):
    """
    Return the subadditivity slack function Delta: (x, y) -> h(x) + h(y) - h(x+y) 
    of the given PiecewisePolynomial_polyhedral function h.

    EXAMPLES::

        sage: logging.disable(logging.INFO)
        sage: fn = gmic(2/3)
        sage: h = piecewise_polynomial_polyhedral_from_fast_piecewise(fn)
        sage: delta = subadditivity_slack_delta(h)
        sage: g = delta.plot_projection(show_values_on_vertices=True)
        sage: delta.plot(domain=polytopes.hypercube(2)) # not tested
        sage: delta(1/2,1/2)
        3/2
        sage: delta(1/5, 1/5)
        0
    """
    n = h.dim()
    Ax = matrix(QQ, n, 2*n, [[1 if j==i else 0 for j in range(2*n)] for i in range(n)])
    Ay = matrix(QQ, n, 2*n,  [[1 if j==i+n else 0 for j in range(2*n)] for i in range(n)])
    hx = h.affine_linear_embedding(Ax)
    hy = h.affine_linear_embedding(Ay)
    hz = h.affine_linear_embedding(Ax+Ay)
    delta = hx + hy - hz
    return delta



def minimality_test_multirow(fn, f=None) :
    """
    Test if the input PiecewisePolynomial_polyhedral function `fn` is a minimal function 
    for the (multi-row) group relaxation with the given `f`.

    Example::
        sage: logging.disable(logging.WARN)             # Suppress output in automatic tests.
        sage: h = gmic(4/5)
        sage: fn = piecewise_polynomial_polyhedral_from_fast_piecewise(h)
        sage: minimality_test_multirow(fn, f=[4/5])
        True
        sage: h = ll_strong_fractional()
        sage: fn = piecewise_polynomial_polyhedral_from_fast_piecewise(h)
        sage: minimality_test_multirow(fn)
        True
        sage: h_vert_strip = fn.affine_linear_embedding(matrix([(1,0)]))
        sage: minimality_test_multirow(h_vert_strip, f=[2/3,2/3])
        True
        sage: minimality_test_multirow(h_vert_strip, f=[1/3,2/3])
        False
        sage: h_diag_strip = fn.affine_linear_embedding(matrix([(1,1)]))
        sage: minimality_test_multirow(h_diag_strip, f=[1/3,1/3])
        True

        sage: h = hildebrand_discont_3_slope_1()
        sage: fn = piecewise_polynomial_polyhedral_from_fast_piecewise(h)
        sage: h_diag_strip = fn.affine_linear_embedding(matrix([(1,1)]))
        sage: minimality_test_multirow(h_diag_strip, f=[1/2,1/2]) #not tested  # does not terminate!
        True
        sage: M = matrix([[0,1/4,1/2],[1/4,1/2,3/4],[1/2,3/4,1]])  # q=3
        sage: fn = PiecewisePolynomial_polyhedral.from_values_on_group_triangulation(M)
        sage: minimality_test_multirow(fn)  # long time # 5 minutes
        True
        sage: PR.<x0,x1>=PolynomialRing(QQ)
        sage: fn = PiecewisePolynomial_polyhedral([(Polyhedron(vertices=[(0,0),(2/3,0),(2/3,2/3),(0,2/3)]), (x0+x1)*3/4), (Polyhedron(vertices=[(1,1),(2/3,1),(2/3,2/3),(1,2/3)]), (2-x0-x1)*3/2), (Polyhedron(vertices=[(1,0),(2/3,0),(2/3,2/3),(1,2/3)]), -3/2*x0 + 3/4*x1 + 3/2), (Polyhedron(vertices=[(0,1),(2/3,1),(2/3,2/3),(0,2/3)]), 3/4*x0 - 3/2*x1 + 3/2)], periodic_extension=True)
        sage: minimality_test_multirow(fn)   # same function as before, minimality test is much faster when it has less pieces.
        True
    """
    if not fn._periodic_extension:
        logging.info('The function is periodic.')
        return False
    if not fn.is_non_negative():
        logging.info('The function is not non-negative.')
        return False
    d = fn.dim()
    cnst_1 = PiecewisePolynomial_polyhedral([(Polyhedron(vertices = itertools.product([0, 1], repeat=d)), 1)], is_continuous=True, check_consistency=False)
    cnst_1._periodic_extension = True
    if not (cnst_1 - fn).is_non_negative():
        logging.info('The function value exceeds 1.')
        return False
    if fn([0]*d) != 0:
        logging.info('The function is not 0 at the origin.')
        return False
    if f is None:
        if hasattr(fn, '_f'):
            f = fn._f
        else:
            preimage_one = fn.preimage(1)
            if not preimage_one:
                raise ValueError, "The function does not have value one."
            f = list(preimage_one[0].vertices()[0])
            if len(preimage_one) > 1 or len(preimage_one[0].Vrepresentation()) > 1:
                logging.warn("There is more than one point where the function takes the value 1; using f = %s.  Provide parameter f to minimality_test or extremality_test if you want a different f." % f)
            fn._f = f
    else:
        f = list(f)
    if not fn(f) == 1:  # quick check, before constructing delta function.
        logging.info('The function does not have value 1 at f.')
        return False
    if hasattr(fn, '_delta'):
        delta = fn._delta
    else:
        delta = subadditivity_slack_delta(fn)
        fn._delta = delta
    domain_z_equals_f = Polyhedron(vertices=[[0]*d+f, [1]*d+[x-1 for x in f]]) # should be a line, but PiecewisePolynomial_polyhedral.restricted_to_domain() can only take bounded domain. We construct a line segment and extend it by periodicity.
    delta_restricted = delta.restricted_to_domain(domain_z_equals_f)
    delta_zero = PiecewisePolynomial_polyhedral([(domain_z_equals_f, 0)], periodic_extension=False, is_continuous=True, check_consistency=False) # symmetric condition
    if not (delta_restricted == delta_zero): # why != (instead of not ==) does not work??
        logging.info('The function is not symmetric.')
        return False
    if not delta.is_non_negative():
        logging.info('The function is not subadditive.')
        return False
    logging.info('The function is a minimal function.')
    return True
