// Marc B. Reynolds, 2013-2016
// Public Domain under http://unlicense.org, see link for details.
//
// Documentation: http://marc-b-reynolds.github.io/shf/2016/04/19/prns.html
//
// Modified by Cloud Wu

#include <stdint.h>

struct random_t {
	uint64_t x;
};

#ifndef PRNS_WEYL
#define PRNS_WEYL   0x61c8864680b583ebL
#define PRNS_WEYL_I 0x0e217c1e66c88cc3L
#endif

#ifndef PRNS_WEYL_D
#define PRNS_WEYL_D 0x4f1bbcdcbfa54001L
#endif

#ifndef PRNS_MIX_S0
#ifdef  PRNS_MIX_13
#define PRNS_MIX_S0 30
#define PRNS_MIX_S1 27
#define PRNS_MIX_S2 31
#define PRNS_MIX_M0 0xbf58476d1ce4e5b9L
#define PRNS_MIX_M1 0x94d049bb133111ebL
#else
#define PRNS_MIX_S0 31
#define PRNS_MIX_S1 27
#define PRNS_MIX_S2 33
#define PRNS_MIX_M0 0x7fb5d329728ea185L
#define PRNS_MIX_M1 0x81dadef4bc2dd44dL
#endif
#endif

#ifndef PRNS_MIX
#ifndef PRNS_SMALLCRUSH
#define PRNS_MIX(X) prns_mix(X)
#else
#define PRNS_MIX(X) prns_min_mix(X)
#endif
#endif 

#ifndef PRNS_MIX_D
#ifndef PRNS_SMALLCRUSH
#define PRNS_MIX_D(X) prns_mix(X)
#else
#define PRNS_MIX_D(X) prns_min_mix(X)
#endif
#endif

static inline uint64_t
prns_mix(uint64_t x) {
	x ^= (x >> PRNS_MIX_S0);
	x *= PRNS_MIX_M0;
	x ^= (x >> PRNS_MIX_S1);	
	x *= PRNS_MIX_M1;

#ifndef PRNS_NO_FINAL_XORSHIFT
	x ^= (x >> PRNS_MIX_S2);
#endif

	return x;
}

void
random_init(struct random_t *rd, uint64_t seed) {
	rd->x = PRNS_MIX(PRNS_WEYL*seed) + PRNS_WEYL_D;
}

uint64_t
random_get(struct random_t *rd) {
	uint64_t i = rd->x;
	uint64_t r = PRNS_MIX_D(i);
	rd->x = i + PRNS_WEYL_D;
	return r;
}

// random [0, range)
int
random_range(struct random_t *rd, int range) {
	uint64_t x = random_get(rd);
	return (int)(x % range);
}

/// lua binding

#include <lua.h>
#include <lauxlib.h>

static int
lrandom_get(lua_State *L) {
	struct random_t r;
	r.x = lua_tointeger(L, lua_upvalueindex(1));
	uint64_t x = random_get(&r);
	lua_pushinteger(L, r.x);
	lua_replace(L, lua_upvalueindex(1));
	uint64_t low, up;
	const uint64_t mask = (((uint64_t)1 << 50) - 1);	// 50bit
	switch (lua_gettop(L)) {
	case 0:
		// return [0,1)
		x &= mask;
		double r = (double)x / (double)(mask+1);
		lua_pushnumber(L, r);
		return 1;
	case 1:
		// return [1, up]
		low = 1;
		up = luaL_checkinteger(L, 1);
		break;
	case 2:
		// return [low, up]
		low = luaL_checkinteger(L, 1);
		up = luaL_checkinteger(L, 2);
		break;
	default:
		return luaL_error(L, "Only support 0/1/2 parms");
	}
	luaL_argcheck(L, low <= up, 1, "interval is empty");
	luaL_argcheck(L, low >= 0 || up <= LUA_MAXINTEGER + low, 1, "interval too large");

	x %= (up - low) + 1;
	lua_pushinteger(L, x + low);

	return 1;
}

static int
lrandom_init(lua_State *L) {
	lua_Integer seed = luaL_checkinteger(L, 1);
	struct random_t r;
	random_init(&r, seed);
	lua_pushinteger(L, r.x);
	lua_pushcclosure(L, lrandom_get, 1);
	return 1;
}

LUAMOD_API int
luaopen_random(lua_State *L) {
	lua_pushcfunction(L, lrandom_init);
	return 1;
}
