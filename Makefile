# <LICENSE
#   Copyright (c) 2013, 2014 Jean-Luc Thiffeault, Marko Budisic
#
#   This file is part of Braidlab.
#
#   Braidlab is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   Braidlab is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with Braidlab.  If not, see <http://www.gnu.org/licenses/>.
# LICENSE>

# Find architecture, set corresponding mex file suffix.
SYS = $(shell uname -s)
ARCH = $(shell uname -m)
ifeq ($(SYS), Linux)
	ifeq ($(ARCH), x86_64)
		MEXSUFFIX = mexa64
	endif
endif
ifeq ($(SYS), Darwin)
	ifeq ($(ARCH), x86_64)
		MEXSUFFIX = mexmaci64
	endif
endif

MEX = mex
CFLAGS = -O -DMATLAB_MEX_FILE
CXXFLAGS = $(CFLAGS) -std=c++0x -fPIC
MEXFLAGS  = -largeArrayDims -O

# Use BRAIDLAB_USE_GMP=1 on command line to compile with GMP.
ifeq ($(BRAIDLAB_USE_GMP), 1)
	GMP_LD = -lgmpxx -lgmp
	MEXFLAGS += -DBRAIDLAB_USE_GMP
endif

MAKE = make MEX=$(MEX) MEXSUFFIX=$(MEXSUFFIX) MEXFLAGS="$(MEXFLAGS)" \
	CXX="$(CXX)" CC="$(CC)" CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" \
	GMP_LD="$(GMP_LD)"

.PHONY: check-env all clean distclean

all: check-env
	cd +braidlab/private; $(MAKE) all
	cd +braidlab/@braid/private; $(MAKE) all
	cd +braidlab/@cfbraid/private; $(MAKE) all
	cd +braidlab/+lcs/private; $(MAKE) all
	cd extern/assignmentoptimal; \
		$(MAKE) all; \
		mv -f assignmentoptimal.mex* ../../+braidlab/private

check-env:
ifndef MEXSUFFIX
	$(error Unknown system/architecture $(SYS)/$(ARCH))
endif

# remove MEX files and object files.
clean:
	cd extern/assignmentoptimal; $(MAKE) clean
	cd extern/cbraid/lib; $(MAKE) clean
	cd extern/trains; $(MAKE) clean
	cd +braidlab/@braid/private; $(MAKE) clean
	cd +braidlab/@cfbraid/private; $(MAKE) clean
	cd +braidlab/+lcs/private; $(MAKE) clean
	cd +braidlab/private; $(MAKE) clean
	cd doc; $(MAKE) clean

# distclean also removes the libraries (useful for recompiling on
# different OS) and the LaTeX-generated files.
distclean: clean
	rm -f extern/cbraid/lib/libcbraid-mex.a
	cd extern/trains; $(MAKE) distclean
	cd doc; $(MAKE) distclean
