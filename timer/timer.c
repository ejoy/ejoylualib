#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#include <lua.h>
#include <lauxlib.h>

#define TIME_NEAR_SHIFT 8
#define TIME_NEAR (1 << TIME_NEAR_SHIFT)
#define TIME_LEVEL_SHIFT 6
#define TIME_LEVEL (1 << TIME_LEVEL_SHIFT)
#define TIME_NEAR_MASK (TIME_NEAR-1)
#define TIME_LEVEL_MASK (TIME_LEVEL-1)

struct timer_node {
	struct timer_node *next;
	uint32_t expire;
	uint32_t session;
};

struct link_list {
	struct timer_node head;
	struct timer_node *tail;
};

struct timer {
	struct link_list near[TIME_NEAR];
	struct link_list t[4][TIME_LEVEL];
	uint32_t time;
	uint32_t starttime;
	uint64_t current;
	uint64_t current_point;
};

static inline struct timer_node *
link_clear(struct link_list *list) {
	struct timer_node * ret = list->head.next;
	list->head.next = 0;
	list->tail = &(list->head);

	return ret;
}

static inline void
link(struct link_list *list,struct timer_node *node) {
	list->tail->next = node;
	list->tail = node;
	node->next=0;
}

static void
add_node(struct timer *T,struct timer_node *node) {
	uint32_t time=node->expire;
	uint32_t current_time=T->time;
	
	if ((time|TIME_NEAR_MASK)==(current_time|TIME_NEAR_MASK)) {
		link(&T->near[time&TIME_NEAR_MASK],node);
	} else {
		int i;
		uint32_t mask=TIME_NEAR << TIME_LEVEL_SHIFT;
		for (i=0;i<3;i++) {
			if ((time|(mask-1))==(current_time|(mask-1))) {
				break;
			}
			mask <<= TIME_LEVEL_SHIFT;
		}

		link(&T->t[i][((time>>(TIME_NEAR_SHIFT + i*TIME_LEVEL_SHIFT)) & TIME_LEVEL_MASK)],node);	
	}
}

static void
timer_add(struct timer *T, unsigned int session, int time) {
	struct timer_node *node = (struct timer_node *)malloc(sizeof(*node));
	if (time < 0)
		time = 0;
	node->session = session;
	node->expire=time+T->time;
	add_node(T,node);
}

static void
move_list(struct timer *T, int level, int idx) {
	struct timer_node *current = link_clear(&T->t[level][idx]);
	while (current) {
		struct timer_node *temp=current->next;
		add_node(T,current);
		current=temp;
	}
}

static void
timer_shift(struct timer *T) {
	int mask = TIME_NEAR;
	uint32_t ct = ++T->time;
	if (ct == 0) {
		move_list(T, 3, 0);
	} else {
		uint32_t time = ct >> TIME_NEAR_SHIFT;
		int i=0;

		while ((ct & (mask-1))==0) {
			int idx=time & TIME_LEVEL_MASK;
			if (idx!=0) {
				move_list(T, i, idx);
				break;				
			}
			mask <<= TIME_LEVEL_SHIFT;
			time >>= TIME_LEVEL_SHIFT;
			++i;
		}
	}
}

static void
timer_init(struct timer *r) {
	memset(r,0,sizeof(*r));

	int i,j;

	for (i=0;i<TIME_NEAR;i++) {
		link_clear(&r->near[i]);
	}

	for (i=0;i<4;i++) {
		for (j=0;j<TIME_LEVEL;j++) {
			link_clear(&r->t[i][j]);
		}
	}

	r->current = 0;
}

static inline void
link_free(struct link_list *list) {
	struct timer_node *current = link_clear(list);
	while (current) {
		struct timer_node * temp = current;
		current=current->next;
		free(temp);	
	}
	link_clear(list);
}

static void
timer_destory(struct timer *T) {
	int i,j;

	for (i=0;i<TIME_NEAR;i++) {
		link_free(&T->near[i]);
	}

	for (i=0;i<4;i++) {
		for (j=0;j<TIME_LEVEL;j++) {
			link_free(&T->t[i][j]);
		}
	}
}

static int
lcreate(lua_State *L) {
	struct timer *t = lua_newuserdata(L, sizeof(struct timer));
	timer_init(t);
	return 1;
}

static int
lrelease(lua_State *L) {
	struct timer *t = lua_touserdata(L, 1);
	timer_destory(t);
	return 0;
}

static int
ladd(lua_State *L) {
	struct timer *T = lua_touserdata(L, 1);
	uint32_t session = luaL_checkinteger(L, 2);
	int time = luaL_checkinteger(L, 3);
	timer_add(T, session, time);
	return 0;
}

static inline void
dispatch_list(lua_State *L, struct timer_node *current, int *n) {
	do {
		struct timer_node * temp = current;
		current=current->next;
		// todo: if rawseti raise (memory) error, cause memory leak
		++*n;
		lua_pushinteger(L, temp->session);
		lua_rawseti(L, -2, *n);

		free(temp);	
	} while (current);
}

static inline int
timer_execute(lua_State *L, struct timer *T) {
	int n = 0;
	int idx = T->time & TIME_NEAR_MASK;
	
	while (T->near[idx].head.next) {
		struct timer_node *current = link_clear(&T->near[idx]);
		// dispatch_list don't need lock T
		dispatch_list(L, current, &n);
	}
	return n;
}

static int
lupdate(lua_State *L) {
	struct timer *T = lua_touserdata(L, 1);
	int elapse = luaL_checkinteger(L, 2);
	luaL_checktype(L, 3, LUA_TTABLE);
	lua_settop(L, 3);

	// try to dispatch timeout 0 (rare condition)
	int n = timer_execute(L, T);

	if (n != 0) {
		lua_pushinteger(L, n);
		lua_pushinteger(L, 0);

		return 2;
	}

	int i;
	for (i=0;i<elapse;i++) {
		// shift time first, and then dispatch timer message
		timer_shift(T);
		int n = timer_execute(L, T);
		if (n != 0) {
			lua_pushinteger(L, n);
			lua_pushinteger(L, i+1);

			return 2;
		}
	}
	lua_pushinteger(L, 0);
	lua_pushinteger(L, elapse);

	return 2;
}

LUAMOD_API int
luaopen_timer_core(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create", lcreate },
		{ "release", lrelease },
		{ "add" , ladd },
		{ "update", lupdate },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
