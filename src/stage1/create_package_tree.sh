#!/bin/bash
 ##############################################################################
 #                      parabola-riscv64-bootstrap                            #
 #                                                                            #
 #    Copyright (C) 2018  Andreas Grapentin                                   #
 #                                                                            #
 #    This program is free software: you can redistribute it and/or modify    #
 #    it under the terms of the GNU General Public License as published by    #
 #    the Free Software Foundation, either version 3 of the License, or       #
 #    (at your option) any later version.                                     #
 #                                                                            #
 #    This program is distributed in the hope that it will be useful,         #
 #    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
 #    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
 #    GNU General Public License for more details.                            #
 #                                                                            #
 #    You should have received a copy of the GNU General Public License       #
 #    along with this program.  If not, see <http://www.gnu.org/licenses/>.   #
 ##############################################################################

set -euo pipefail

msg "creating transitive dependency tree for $_groups"

if [ ! -f "$_deptree" ]; then
  declare -A _tree

  # remove a couple things from base we don't need
  _frontier=($(pacman -Sg $_groups | awk '{print $2}' \
    | grep -v lvm2 \
    | grep -v mdadm))

  while [ ${#_frontier[@]} -gt 0 ]; do
    # pop pkg from frontier
    _pkgname=$(echo ${_frontier[0]})
    _frontier=("${_frontier[@]:1}")

    # if seen before, skip, otherwise create entry in dependency tree
    [[ -v _tree[$_pkgname] ]] && continue
    _tree[$_pkgname]=""

    _pkgdeps=$(pacman -Si $_pkgname | grep '^Depends' | cut -d':' -f2 | sed 's/None//')

    # iterate dependencies for pkg
    for dep in $_pkgdeps; do
      # translate dependency string to actual package
      realdep=$(pacman --noconfirm -Sw "$dep" | grep '^Packages' | awk '{print $3}')
      realdep=${realdep%-*-*}
      # add dependency to tree and frontier
      _tree[$_pkgname]="${_tree[$_pkgname]} $realdep"
      _frontier+=($realdep)
    done
  done

  # add some additional build-order dependencies by hand
  _tree[libutil-linux]="${_tree[libutil-linux]}pam libcap-ng ncurses "
  _tree[gcc-libs]="${_tree[gcc-libs]}libmpfr "

  # log package dependency tree
  truncate -s0 "$_deptree".FULL
  for i in "${!_tree[@]}"; do
    echo "${i} : [${_tree[$i]} ]" >> "$_deptree".FULL
  done
fi

[ -n "${CONTINUE:-}" ] || cp "$_deptree"{.FULL,}

echo "total pkges: $(cat "$_deptree".FULL | wc -l)"
