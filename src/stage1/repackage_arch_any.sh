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

set -eu

_packages=$(cat "$_builddir"/DEPTREE | cut -d' ' -f1)

# we can simply repackage anything with arch=('any'), no compilation needed.
for _pkgname in $_packages; do
  _pkgarch=$(pacman -Si $_pkgname | grep '^Architecture' | awk '{print $3}')
  [ "x$_pkgarch" == "xany" ] || continue

  _pkgver=$(pacman -Qi $_pkgname | grep '^Version' | awk '{print $3}')
  _pkgdir="$_makepkgdir"/$_pkgname/pkg/$_pkgname

  msg "makepkg: $_pkgname-$_pkgver-any.pkg.tar.xz"
  msg "  remaining pkges: $(cat "$_deptree" | wc -l)"

  if [ ! -f "$_makepkgdir"/$_pkgname-$_pkgver-any.pkg.tar.xz ]; then
    rm -rf "$_makepkgdir"/$_pkgname
    mkdir -pv "$_makepkgdir"/$_pkgname
    pushd "$_makepkgdir"/$_pkgname >/dev/null

    # download the package
    pacman -Sw --noconfirm --cachedir . $_pkgname
    cp $_pkgname-$_pkgver-any.pkg.tar.xz "$_makepkgdir"/

    popd >/dev/null

    # rm -rf "$_makepkgdir"/$_pkgname
  fi

  cp -av "$_makepkgdir"/$_pkgname-$_pkgver-any.pkg.tar.xz "$_chrootdir"/packages/$_arch

  rm -rf "$_chrootdir"/var/cache/pacman/pkg/*
  rm -rf "$_chrootdir"/packages/$_arch/repo.{db,files}*
  repo-add -q -R "$_chrootdir"/packages/$_arch/{repo.db.tar.gz,*.pkg.tar.xz}
  pacman --noscriptlet --noconfirm --force -dd --config "$_chrootdir"/etc/pacman.conf \
    -r "$_chrootdir" -Syy $_pkgname

  # remove pkg from deptree
  sed -i "/^$_pkgname :/d; s/ $_pkgname / /" "$_deptree"
done