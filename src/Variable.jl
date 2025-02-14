function nvalues(v::CS.Variable)
    return v.last_ptr-v.first_ptr+1
end

function value(v::CS.Variable)
    return v.values[v.last_ptr]
end

function values(v::CS.Variable)
    return v.values[v.first_ptr:v.last_ptr]
end

function issetto(v::CS.Variable, x::Int)
    if !isfixed(v) 
        return false
    else
        return x == value(v)
    end
end

function has(v::CS.Variable, x::Int)
    if x > v.to || x < v.from
        return false
    end
    ind = v.indices[x+v.offset]
    return v.first_ptr <= ind <= v.last_ptr
end

function rm!(com::CS.CoM, v::CS.Variable, x::Int; in_remove_several=false, changes=true)
    if !in_remove_several
        # after removing nothing would be possible
        len_vals = nvalues(v)
        if len_vals == 1
            com.bt_infeasible[v.idx] += 1
            return false
        elseif len_vals == 2
            possible = values(v)
            left_over = possible[1] == x ? possible[2] : possible[1]
            if !fulfills_constraints(com, v.idx, left_over)
                com.bt_infeasible[v.idx] += 1
                return false
            end
        end
    end

    ind = v.indices[x+v.offset]
    v.indices[x+v.offset], v.indices[v.values[v.last_ptr]+v.offset] = v.indices[v.values[v.last_ptr]+v.offset], v.indices[x+v.offset]
    v.values[ind], v.values[v.last_ptr] = v.values[v.last_ptr], v.values[ind]
    v.last_ptr -= 1
    if !in_remove_several 
        vals = values(v)
        if length(vals) > 0
            if x == v.min 
                v.min = minimum(vals)
            end
            if x == v.max
                v.max = maximum(vals)
            end
        end
        changes && push!(v.changes[com.c_backtrack_idx], (:rm, x, 0, 1))
    end
    return true
end

function fix!(com::CS.CoM, v::CS.Variable, x::Int; changes=true)
    if !fulfills_constraints(com, v.idx, x)
        com.bt_infeasible[v.idx] += 1
        return false
    end
    ind = v.indices[x+v.offset]
    pr_below = ind-v.first_ptr
    pr_above = v.last_ptr-ind
    changes && push!(v.changes[com.c_backtrack_idx], (:fix, x, v.last_ptr, 0))
    v.last_ptr = ind
    v.first_ptr = ind
    v.min = x
    v.max = x
    return true
end

function isfixed(v::CS.Variable)
    return v.last_ptr == v.first_ptr
end

function remove_below!(com::CS.CoM, var::CS.Variable, val::Int; changes=true)
    vals = values(var)
    still_possible = filter(v -> v >= val, vals)
    if length(still_possible) == 0
        com.bt_infeasible[var.idx] += 1
        return false
    elseif length(still_possible) == 1
        if !fulfills_constraints(com, var.idx, still_possible[1])
            com.bt_infeasible[var.idx] += 1
            return false
        end
    end

    nremoved = 0
    for v in vals
        if v < val
            rm!(com, var, v; in_remove_several = true)
            nremoved += 1
        end
    end
    if nremoved > 0 && feasible(var)
        var.min = minimum(values(var))
        changes && push!(var.changes[com.c_backtrack_idx], (:remove_below, val, 0, nremoved))
    end
    return true
end

function remove_above!(com::CS.CoM, var::CS.Variable, val::Int; changes=true)
    vals = values(var)
    still_possible = filter(v -> v <= val, vals)
    if length(still_possible) == 0
        com.bt_infeasible[var.idx] += 1
        return false
    elseif length(still_possible) == 1
        if !fulfills_constraints(com, var.idx, still_possible[1])
            com.bt_infeasible[var.idx] += 1
            return false
        end
    end

    nremoved = 0
    for v in vals
        if v > val
            rm!(com, var, v; in_remove_several = true)
            nremoved += 1
        end
    end
    if nremoved > 0 && feasible(var)
        var.max = maximum(values(var))
        changes && push!(var.changes[com.c_backtrack_idx], (:remove_above, val, 0, nremoved))
    end
    return true
end

function feasible(var::CS.Variable)
    return var.last_ptr >= var.first_ptr
end