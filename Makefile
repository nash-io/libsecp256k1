MIX = mix

LIBTOOL ?= libtool
ERLANG_PATH ?= $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS += -I"$(ERLANG_PATH)"
CFLAGS += -I c_src/secp256k1 -I c_src/secp256k1/src -I c_src/secp256k1/include
CFLAGS += -I c_src/gmp-6.2.1/
CFLAGS += -I$(../libsecp256k1)/src

ifneq ($(OS),Windows_NT)
CFLAGS += -fPIC
endif

LIBSECP256K1 = c_src/secp256k1/.libs/libsecp256k1.a
LIBGMP = c_src/gmp-6.2.1/.libs/libgmp.a

GMPFLAGS = --with-pic=yes --disable-shared
ifneq (,$(findstring ios,$(HOST)))
GMPFLAGS += --disable-assembly
endif

ifneq (,$(HOST))
HOSTFLAG = --host=$(HOST)
endif

EXTRALIBS += $(LIBSECP256K1) $(LIBGMP)

.PHONY: clean

ifeq ($(STATIC_ERLANG_NIF),)
ifeq ($(shell uname),Darwin)
LDFLAGS += -dynamiclib -undefined dynamic_lookup
endif

all: priv/libsecp256k1_nif.so
else
CFLAGS += -DSTATIC_ERLANG_NIF=1
CXXFLAGS += -DSTATIC_ERLANG_NIF=1

# For static libs the basename "libsecp256k1" and the nif name in ERL_NIF_INIT() must match
all: priv/libsecp256k1.a
endif

priv/libsecp256k1_nif.so: c_src/libsecp256k1_nif.c $(EXTRALIBS)
	$(CC) $(CFLAGS) -shared -o $@ c_src/libsecp256k1_nif.c $(EXTRALIBS) $(LDFLAGS)

c_src/libsecp256k1_nif.o: $(EXTRALIBS)
priv/libsecp256k1.a: c_src/libsecp256k1_nif.o
	$(LIBTOOL) -static -o $@ c_src/libsecp256k1_nif.o $(EXTRALIBS)

$(LIBSECP256K1): c_src/secp256k1
	cd c_src/secp256k1 && git reset --hard d33352151699bd7598b868369dace092f7855740 && ./autogen.sh && ./configure --enable-module-recovery $(HOSTFLAG)
	$(MAKE) -C c_src/secp256k1

c_src/secp256k1:
	cd c_src && git clone https://github.com/bitcoin/secp256k1

$(LIBGMP): c_src/gmp-6.2.1
	cd c_src/gmp-6.2.1 && ./configure $(HOSTFLAG) $(GMPFLAGS)
	$(MAKE) -C c_src/gmp-6.2.1

c_src/gmp-6.2.1:
	cd c_src && wget https://gmplib.org/download/gmp/gmp-6.2.1.tar.xz && tar xJf gmp-6.2.1.tar.xz


clean:
	$(MIX) clean
	-rm -rf c_src/secp256k1 c_src/gmp-6.2.1
	$(RM) priv/libsecp256k1_nif.so
