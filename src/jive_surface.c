/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"
#include "jive.h"
#include "savepng.h"

#include <pthread.h>
#include <stdio.h>

/*
 * This file combines both JiveSurface and JiveTile into a single implementation.
 * The separate typdefs, JiveSurface and JiveTile, are still kept so that the
 * relationship to the two generated Lua classes, Surface and Tile, is visible.
 * However, the external Lua/C that uses these classes already mixed up use of
 * the two classes, which is a large part of the motivation for combining them.
 *
 */

struct loaded_image_surface {
	Uint16 image;								/* index to underlying struct image */
	SDL_Surface *srf;
	struct loaded_image_surface *prev, *next;	/* LRU cache double-linked list */
};

/* locked images (no path) are not counted or kept in the LRU list */
#define MAX_LOADED_IMAGES 75
static struct loaded_image_surface lruHead, lruTail;
static Uint16 nloadedImages;

struct image {
	const char * path;
	Uint16 w;
	Uint16 h;
	Uint16 flags;
#   define IMAGE_FLAG_INIT  (1<<0)			/* Have w & h been evaluated yet */
#   define IMAGE_FLAG_AMASK (1<<1)
	Uint16 ref_count;
#ifdef JIVE_PROFILE_IMAGE_CACHE
	Uint16 use_count;
	Uint16 load_count;
#endif
	struct loaded_image_surface * loaded;	/* reference to loaded surface */
	struct jive_surface *tile;				/* reference to image tile for this image, if there is one */
};

/* We do not use image 0 - it is just easier to let 0 mean no image */
#define INITIAL_IMAGES		500		// Enough for two skins on fab4
#define ADDITIONAL_IMAGES	100		// How much to increment by
#define MAX_IMAGES			2000	// safety limit
static Uint16 image_pool_size;
static struct image *images;
static Uint16 n_images = 1;

struct jive_surface {
	Uint32 refcount;

	/* Fields for simple surfaces */
	SDL_Surface *sdl;
	Sint16 offset_x, offset_y;

	/* Fields for tiles */
	Uint16 image[9];
	Uint16 w[2];
	Uint16 h[2];
	Uint32 bg;
	Uint32 alpha_flags;

	Uint16 flags;
#   define TILE_FLAG_INIT  (1<<0)		/* Have w & h been evaluated yet */
#   define TILE_FLAG_BG    (1<<1)
#   define TILE_FLAG_ALPHA (1<<2)		/* have alpha flags been set of this tile */
#   define TILE_FLAG_spare (1<<3)
#   define TILE_FLAG_IMAGE (1<<4)		/* just a single image */
#   define TILE_FLAG_TILE  (1<<5)		/* multiple images */
};

#define IS_DYNAMIC_IMAGE(tile) ((tile)->flags & (TILE_FLAG_IMAGE | TILE_FLAG_TILE))

static int _new_image(const char *path) {
	Uint16 i;

	if (image_pool_size == 0) {
		image_pool_size = INITIAL_IMAGES;
		images = calloc(image_pool_size, sizeof(images[0]));
		if (!images) {
			LOG_ERROR(log_ui_draw, "Cannot allocate image pool");
			/* should probably be a fatal error */
			return 0;
		}
	}

	for (i = 0; i < n_images; i++) {
		if (images[i].ref_count <= 0)
			break;
		if (images[i].path && strcmp(path, images[i].path) == 0) {
			images[i].ref_count++;
			return i;
		}
	}

	/* Allocate or extend image pool as necessary */
	if (i >= image_pool_size) {
		if (i >= MAX_IMAGES) {
			LOG_ERROR(log_ui_draw, "Maximum number of images (%d) exceeded for %s", MAX_IMAGES, path);
			return 0;
		}

		images = realloc(images, (image_pool_size + ADDITIONAL_IMAGES) * sizeof(images[0]));
		if (!images) {
			LOG_ERROR(log_ui_draw, "Cannot extend image pool from %d entries by %d entries", image_pool_size, ADDITIONAL_IMAGES);
			image_pool_size = 0;
			/* should probably be a fatal error */
			return 0;
		}
		memset(&images[image_pool_size], 0, ADDITIONAL_IMAGES * sizeof(images[0]));
		image_pool_size += ADDITIONAL_IMAGES;
	}

	if (i == n_images)
		n_images++;
	images[i].path = strdup(path);
	images[i].ref_count = 1;
	return i;
}

static void _unload_image(Uint16 index) {
	struct loaded_image_surface *loaded = images[index].loaded;

	if (loaded->next) {
		nloadedImages--;	/* only counted if actually in LRU list */
		loaded->prev->next = loaded->next;
		loaded->next->prev = loaded->prev;
	}

#ifdef JIVE_PROFILE_IMAGE_CACHE
	LOG_DEBUG(log_ui_draw, "Unloading  %3d:%s", index, images[index].path);
#endif

	SDL_FreeSurface(loaded->srf);
	free(loaded);
	images[index].loaded = 0;
}

static void _use_image(Uint16 index) {
	struct loaded_image_surface *loaded = images[index].loaded;

#ifdef JIVE_PROFILE_IMAGE_CACHE
	images[index].use_count++;
#endif

	/* short-circuit if already at head */
	if (loaded->prev == &lruHead)
		return;

	/* ignore locked images */
	if (images[index].path == 0)
		return;

	/* init head and tail if needed */
	if (lruHead.next == 0) {
		lruHead.next = &lruTail;
		lruTail.prev = &lruHead;
	}

	/* If already in the list then just move to head */
	if (loaded->next) {

		/* cut out */
		loaded->prev->next = loaded->next;
		loaded->next->prev = loaded->prev;

		/* insert at head */
		loaded->next = lruHead.next;
		loaded->next->prev = loaded;
		loaded->prev = &lruHead;
		lruHead.next = loaded;
	}

	/* otherwise, insert at head and eject oldest if necessary */
	else {
		/* insert at head */
		loaded->next = lruHead.next;
		loaded->next->prev = loaded;
		loaded->prev = &lruHead;
		lruHead.next = loaded;

		if (++nloadedImages > MAX_LOADED_IMAGES) {
			_unload_image(lruTail.prev->image);
		}
	}
}

static void _load_image (Uint16 index, bool hasAlphaFlags, Uint32 alphaFlags) {
	struct image *image = &images[index];
	SDL_Surface *tmp, *srf;

	tmp = IMG_Load(image->path);
	if (!tmp) {
		LOG_WARN(log_ui_draw, "Error loading tile image %s: %s\n", image->path, IMG_GetError());
		return;
	}
	if (tmp->format->Amask) {
		srf = SDL_DisplayFormatAlpha(tmp);
		image->flags |= IMAGE_FLAG_AMASK;
	} else {
		srf = SDL_DisplayFormat(tmp);
	}
	SDL_FreeSurface(tmp);

	if (!srf)
		return;

	if (hasAlphaFlags) {
		SDL_SetAlpha(srf, alphaFlags, 0);
	}

	image->loaded = calloc(sizeof *(image->loaded), 1);
	image->loaded->image = index;
	image->loaded->srf = srf;

#ifdef JIVE_PROFILE_IMAGE_CACHE
	image->load_count++;
#endif

	if (!(image->flags & IMAGE_FLAG_INIT)) {
		image->w = srf->w;
		image->h = srf->h;
		image->flags |= IMAGE_FLAG_INIT;
	}

	_use_image(index);

#ifdef JIVE_PROFILE_IMAGE_CACHE
	LOG_DEBUG(log_ui_draw, "Loaded image %3d:%s", index, image->path);
#endif
}

static void _load_tile_images (JiveTile *tile) {
	int i, max;

#ifdef JIVE_PROFILE_IMAGE_CACHE
	int n = 0, m = 0;
#endif

	/* shortcut for images */
	max =  (tile->flags & TILE_FLAG_IMAGE) ? 1 : 9;

	/* make two passes to avoid the unload/load shuttle problem */
	for (i = 0; i < max; i++) {
		Uint16 image = tile->image[i];

		if (!image)
			continue;

		if (images[image].loaded)
			_use_image(image);
	}

	for (i = 0; i < max; i++) {
		Uint16 image = tile->image[i];

		if (!image)
			continue;

		if (!images[image].loaded) {

#ifdef JIVE_PROFILE_IMAGE_CACHE
			if (images[image].flags & IMAGE_FLAG_INIT)
				m++;
			n++;
#endif

			_load_image(image, tile->flags & TILE_FLAG_ALPHA, tile->alpha_flags);
		}
	}

#ifdef JIVE_PROFILE_IMAGE_CACHE
	if (n) {
		int loaded = 0;
		for (i = 0; i < n_images; i++) {
			if (images[i].loaded)
				loaded++;
		}
		LOG_DEBUG(log_ui_draw, "Loaded %d new images, %d already inited; %d of %d now loaded", n, m, loaded, n_images);
	}
#endif

}

static void _init_image_sizes(struct image *image) {
	if (image->loaded) {
		image->w = image->loaded->srf->w;
		image->h = image->loaded->srf->h;
	} else {
		SDL_Surface *tmp;

#ifdef JIVE_PROFILE_IMAGE_CACHE
		 LOG_DEBUG(log_ui_draw, "Loading image just for sizes: %s", image->path);
#endif

		tmp = IMG_Load(image->path);
		if (!tmp) {
			LOG_WARN(log_ui_draw, "Error loading tile image %s: %s\n", image->path, IMG_GetError());
			image->flags |= IMAGE_FLAG_INIT;	/* fake it - no point in trying repeatedly */
			return;
		}
		if (tmp->format->Amask)
			image->flags |= IMAGE_FLAG_AMASK;

		image->w = tmp->w;
		image->h = tmp->h;

		SDL_FreeSurface(tmp);
	}
	image->flags |= IMAGE_FLAG_INIT;
}

static Uint16 _get_image_w(struct image *image) {
	if (!(image->flags & IMAGE_FLAG_INIT))
		_init_image_sizes(image);
	return image->w;
}

static Uint16 _get_image_h(struct image *image) {
	if (!(image->flags & IMAGE_FLAG_INIT))
		_init_image_sizes(image);
	return image->h;
}

static void _init_tile_sizes(JiveTile *tile) {
	if (tile->flags & TILE_FLAG_INIT)
		return;

	/* top left */
	if (tile->image[1]) {
		tile->w[0] = MAX(_get_image_w(&images[tile->image[1]]), tile->w[0]);
		tile->h[0] = MAX(_get_image_h(&images[tile->image[1]]), tile->h[0]);
	}

	/* top right */
	if (tile->image[3]) {
		tile->w[1] = MAX(_get_image_w(&images[tile->image[3]]), tile->w[1]);
		tile->h[0] = MAX(_get_image_h(&images[tile->image[3]]), tile->h[0]);
	}

	/* bottom right */
	if (tile->image[5]) {
		tile->w[1] = MAX(_get_image_w(&images[tile->image[5]]), tile->w[1]);
		tile->h[1] = MAX(_get_image_h(&images[tile->image[5]]), tile->h[1]);
	}

	/* bottom left */
	if (tile->image[7]) {
		tile->w[0] = MAX(_get_image_w(&images[tile->image[7]]), tile->w[0]);
		tile->h[1] = MAX(_get_image_h(&images[tile->image[7]]), tile->h[1]);
	}

	/* top */
	if (tile->image[2]) {
		tile->h[0] = MAX(_get_image_h(&images[tile->image[2]]), tile->h[0]);
	}

	/* right */
	if (tile->image[4]) {
		tile->w[1] = MAX(_get_image_w(&images[tile->image[4]]), tile->w[1]);
	}

	/* bottom */
	if (tile->image[6]) {
		tile->h[1] = MAX(_get_image_h(&images[tile->image[6]]), tile->h[1]);
	}

	/* left */
	if (tile->image[8]) {
		tile->w[0] = MAX(_get_image_w(&images[tile->image[8]]), tile->w[0]);
	}

	/* special for single images */
	if (tile->image[0] && !tile->image[1] && !tile->w[0]) {
		tile->w[0] = _get_image_w(&images[tile->image[0]]);
		tile->h[0] = _get_image_h(&images[tile->image[0]]);
	}

	tile->flags |= TILE_FLAG_INIT;
}

static void _get_tile_surfaces(JiveTile *tile, SDL_Surface *srf[9], bool load) {
	int i;

	if (load)
		_load_tile_images(tile);

	for (i = 0; i < 9; i++) {
		if (tile->image[i] && images[tile->image[i]].loaded) {
			srf[i] = images[tile->image[i]].loaded->srf;
		} else {
			srf[i] = 0;
		}
	}
}

static SDL_Surface *get_image_surface(JiveTile *tile) {
	if (!IS_DYNAMIC_IMAGE(tile)) {
		//LOG_ERROR(log_ui_draw, "no SDL surface available");
		return NULL;
	}

	_load_tile_images(tile);
	if (!images[tile->image[0]].loaded)
		return NULL;

	return images[tile->image[0]].loaded->srf;
}

static inline SDL_Surface * _resolve_SDL_surface(JiveSurface *srf) {
	if (srf->sdl)
		return srf->sdl;
	return get_image_surface(srf);
}

JiveTile *jive_tile_fill_color(Uint32 col) {
	JiveTile *tile;

	tile = calloc(sizeof(JiveTile), 1);
	tile->refcount = 1;

	tile->flags = TILE_FLAG_INIT | TILE_FLAG_BG;
	tile->bg = col;

	return tile;
}

JiveTile *jive_tile_load_image(const char *path) {
	JiveTile *tile;
	char *fullpath;
	Uint16 image;

	if (!path) {
		return NULL;
	}

	fullpath = malloc(PATH_MAX);

	if (!jive_find_file(path, fullpath)) {
		LOG_ERROR(log_ui_draw, "Can't find image %s\n", path);
		free(fullpath);
		return NULL;
	}

	image = _new_image(fullpath);
	free(fullpath);

	if (images[image].tile) {
		images[image].ref_count--;
		tile = jive_tile_ref(images[image].tile);
	} else {
		tile = calloc(sizeof(JiveTile), 1);
		tile->image[0] = image;
		tile->refcount = 1;
		tile->flags = TILE_FLAG_IMAGE;
		images[image].tile = tile;
	}

	return tile;
}


JiveTile *jive_tile_load_image_data(const char *data, size_t len) {
	JiveTile *tile;
	SDL_Surface *tmp, *srf;
	SDL_RWops *src;

	tile = calloc(sizeof(JiveTile), 1);
	tile->refcount = 1;

	src = SDL_RWFromConstMem(data, (int) len);
	tmp = IMG_Load_RW(src, 1);

	if (!tmp) {
		LOG_WARN(log_ui_draw, "Error loading tile: %s\n", IMG_GetError());
		free(tile);
		return NULL;
	}
	else {
		if (tmp->format->Amask) {
			srf = SDL_DisplayFormatAlpha(tmp);
		}
		else {
			srf = SDL_DisplayFormat(tmp);
		}
		SDL_FreeSurface(tmp);
	}

	tile->sdl = srf;

	return tile;
}

JiveTile *jive_tile_load_tiles(char *path[9]) {
	JiveTile *tile;
	char *fullpath;
	int i;
	int found = 0;

	tile = calloc(sizeof(JiveTile), 1);
	tile->refcount = 1;
	tile->flags = TILE_FLAG_TILE;

	fullpath = malloc(PATH_MAX);

	for (i=0; i<9; i++) {
		if (!path[i]) {
			continue;
		}

		if (!jive_find_file(path[i], fullpath)) {
			LOG_ERROR(log_ui_draw, "Can't find image %s\n", path[i]);
			continue;
		}

		tile->image[i] = _new_image(fullpath);
		found++;
	}

	free(fullpath);

	if (!found) {
		LOG_ERROR(log_ui_draw, "No images found - no tile created");
		free(tile);
		return NULL;
	}

	return tile;
}

JiveTile *jive_tile_load_vtiles(char *path[3]) {
	char *path2[9];

	memset(path2, 0, sizeof(path2));
	path2[1] = path[0];
	path2[8] = path[1];
	path2[7] = path[2];

	return jive_tile_load_tiles(path2);
}


JiveTile *jive_tile_load_htiles(char *path[3]) {
	char *path2[9];

	memset(path2, 0, sizeof(path2));
	path2[1] = path[0];
	path2[2] = path[1];
	path2[3] = path[2];

	return jive_tile_load_tiles(path2);
}

JiveTile *jive_tile_ref(JiveTile *tile) {
	if (tile) {
		tile->refcount++;
	}
	return tile;
}

void jive_tile_get_min_size(JiveTile *tile, Uint16 *w, Uint16 *h) {

	if (tile->sdl) {
		if (w) *w = tile->sdl->w;
		if (h) *h = tile->sdl->h;
		return;
	}

	_init_tile_sizes(tile);

	if (w) *w = tile->w[0] + tile->w[1];
	if (h) *h = tile->h[0] + tile->h[1];
}

void jive_tile_set_alpha(JiveTile *tile, Uint32 flags) {
	SDL_Surface *srf[9];
	int i;

	if (tile->sdl) {
		SDL_SetAlpha(tile->sdl, flags, 0);
		return;
	}

	tile->alpha_flags = flags;
	tile->flags |= TILE_FLAG_ALPHA;

	_get_tile_surfaces(tile, srf, false);
	for (i=0; i<9; i++) {
		if (srf[i]) {
			SDL_SetAlpha(srf[i], flags, 0);
		}
	}
}

void jive_tile_free(JiveTile *tile) {
	int i;

	if (--tile->refcount > 0) {
		return;
	}

	if (tile->sdl) {
		SDL_FreeSurface (tile->sdl);
		tile->sdl = NULL;
	}

	else for (i=0; i<9; i++) {
		struct image *image;

		if (!tile->image[i])
			continue;

		image = &images[tile->image[i]];
		if (--image->ref_count > 0) {

			/* Was this the single-image tile using this image? */
			if (image->tile == tile)
				image->tile = 0;

			continue;
		}

		if (image->loaded) {
			_unload_image(tile->image[i]);
		}
		memset(image, 0, sizeof *image);
	}

	free(tile);
}

static __inline__ void blit_area(SDL_Surface *src, SDL_Surface *dst, int dx, int dy, int dw, int dh) {
	SDL_Rect sr, dr;
	int x, y, w, h;
	int tw, th;

	tw = src->w;
	th = src->h;

	sr.x = 0;
	sr.y = 0;

	h = dh;
	y = dy;
	while (h > 0) {
		w = dw;
		x = dx;
		while (w > 0) {
			sr.w = w;
			sr.h = h;
			dr.x = x;
			dr.y = y;

			SDL_BlitSurface(src, &sr, dst, &dr);

			x += tw;
			w -= tw;
		}

		y += th;
		h -= th;
	}
}

/* this function must only be used for blitting tiles */
void jive_surface_get_tile_blit(JiveSurface *srf, SDL_Surface **sdl, Sint16 *x, Sint16 *y) {
	*sdl = _resolve_SDL_surface(srf);
	*x = srf->offset_x;
	*y = srf->offset_y;
}


static void _blit_tile(JiveTile *tile, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint16 dw, Uint16 dh) {
	int ox=0, oy=0, ow=0, oh=0;
	Sint16 dst_offset_x, dst_offset_y;
	SDL_Surface *dst_srf;
	SDL_Surface *srf[9];

	if (tile->flags & TILE_FLAG_BG) {
		jive_surface_boxColor(dst, dx, dy, dx + dw - 1, dy + dh - 1, tile->bg);
		return;
	}

	jive_surface_get_tile_blit(dst, &dst_srf, &dst_offset_x, &dst_offset_y);

	dx += dst_offset_x;
	dy += dst_offset_y;

	if (tile->sdl) {
		/* simple, data-loaded image */
		blit_area(tile->sdl, dst_srf, dx, dy, dw, dh);
		return;
	}

	_get_tile_surfaces(tile, srf, true);
	_init_tile_sizes(tile);

	if ((tile->flags & TILE_FLAG_IMAGE) && srf[0]) {
		/* dynamically-loaded image */
		blit_area(srf[0], dst_srf, dx, dy, dw, dh);
		return;
	}

	/* top left */
	if (srf[1]) {
		ox = MIN(tile->w[0], dw);
		oy = MIN(tile->h[0], dh);
		blit_area(srf[1], dst_srf, dx, dy, ox, oy);
	}

	/* top right */
	if (srf[3]) {
		ow = MIN(tile->w[1], dw);
		oy = MIN(tile->h[0], dh);
		blit_area(srf[3], dst_srf, dx + dw - ow, dy, ow, oy);
	}

	/* bottom right */
	if (srf[5]) {
		ow = MIN(tile->w[1], dw);
		oh = MIN(tile->h[1], dh);
		blit_area(srf[5], dst_srf, dx + dw - ow, dy + dh - oh, ow, oh);
	}

	/* bottom left */
	if (srf[7]) {
		ox = MIN(tile->w[0], dw);
		oh = MIN(tile->h[1], dh);
		blit_area(srf[7], dst_srf, dx, dy + dh - oh, ox, oh);
	}

	/* top */
	if (srf[2]) {
		oy = MIN(tile->h[0], dh);
		blit_area(srf[2], dst_srf, dx + ox, dy, dw - ox - ow, oy);
	}

	/* right */
	if (srf[4]) {
		ow = MIN(tile->w[1], dw);
		blit_area(srf[4], dst_srf, dx + dw - ow, dy + oy, ow, dh - oy - oh);
	}

	/* bottom */
	if (srf[6]) {
		oh = MIN(tile->h[1], dh);
		blit_area(srf[6], dst_srf, dx + ox, dy + dh - oh, dw - ox - ow, oh);
	}

	/* left */
	if (srf[8]) {
		ox = MIN(tile->w[0], dw);
		blit_area(srf[8], dst_srf, dx, dy + oy, ox, dh - oy - oh);
	}

	/* center */
	if (srf[0]) {
		blit_area(srf[0], dst_srf, dx + ox, dy + oy, dw - ox - ow, dh - oy - oh);
	}
}


void jive_tile_blit(JiveTile *tile, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint16 dw, Uint16 dh) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT
	Uint16 mw, mh;

	if (!dw || !dh) {
		jive_tile_get_min_size(tile, &mw, &mh);
		if (!dw) {
			dw = mw;
		}
		if (!dh) {
			dh = mh;
		}
	}

	_blit_tile(tile, dst, dx, dy, dw, dh);

#ifdef JIVE_PROFILE_BLIT
	t1 = jive_jiffies();
	printf("\tjive_tile_blit took=%d\n", t1-t0);
#endif //JIVE_PROFILE_BLIT
}


void jive_tile_blit_centered(JiveTile *tile, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint16 dw, Uint16 dh) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT
	Uint16 mw, mh;

	jive_tile_get_min_size(tile, &mw, &mh);
	if (dw < mw) {
		dw = mw;
	}
	if (dh < mh) {
		dh = mh;
	}

	_blit_tile(tile, dst, dx - (dw/2), dy -  (dh/2), dw, dh);

#ifdef JIVE_PROFILE_BLIT
	t1 = jive_jiffies();
	printf("\tjive_tile_blit_centered took=%d\n", t1-t0);
#endif //JIVE_PROFILE_BLIT
}


JiveSurface *jive_surface_set_video_mode(Uint16 w, Uint16 h, Uint16 bpp, bool fullscreen) {
	JiveSurface *srf;
	SDL_Surface *sdl;
	Uint32 flags;

	LOG_INFO(log_ui_draw, "set_video_mode: WxH=%dx%d, bpp=%d, fullscreen=%d", (int)w, (int)h, (int)bpp, (int)fullscreen);
	if (fullscreen) {
		flags = SDL_FULLSCREEN;
	}
	else {
		flags = SDL_HWSURFACE | SDL_DOUBLEBUF | SDL_RESIZABLE;
	}

	sdl = SDL_GetVideoSurface();
	if (sdl) {
		const SDL_VideoInfo *video_info;
		Uint32 mask;

		LOG_INFO(log_ui_draw, "set_video_mode: SDL_GetVideoSurface() returned: sdl flags %x", sdl->flags);

		/* check if we can reuse the existing suface? */
		video_info = SDL_GetVideoInfo();
		if (video_info->wm_available) {
			mask = (SDL_FULLSCREEN | SDL_HWSURFACE | SDL_DOUBLEBUF | SDL_RESIZABLE);
		}
		else {
			mask = (SDL_HWSURFACE | SDL_DOUBLEBUF);
		}

		if ((sdl->w != w) || (sdl->h != h)
			|| (bpp && sdl->format->BitsPerPixel != bpp)
			|| ((sdl->flags & mask) != (flags & mask))) {
			LOG_INFO(log_ui_draw, "set_video_mode: reconfiguring");
			sdl = NULL;
		}
	}

	if (!sdl) {
		/* create new surface */
		LOG_INFO(log_ui_draw, "set_video_mode: setting: WxH=%dx%d, bpp=%d, flags=%x",
				(int)w, (int)h, (int)bpp, flags);

		sdl = SDL_SetVideoMode(w, h, bpp, flags);
		if (!sdl) {
			LOG_ERROR(log_ui_draw, "SDL_SetVideoMode(%d,%d,%d): %s",
				  w, h, bpp, SDL_GetError());
			return NULL;
		}

		if ( (sdl->flags & SDL_HWSURFACE) && (sdl->flags & SDL_DOUBLEBUF)) {
			LOG_INFO(log_ui_draw, "Using a hardware double buffer");
		}

	}
//	LOG_INFO(log_ui_draw, "Video mode : %d bits/pixel %d bytes/pixel [R<<%d G<<%d B<<%d] flags=%x", sdl->format->BitsPerPixel, sdl->format->BytesPerPixel, sdl->format->Rshift, sdl->format->Gshift, sdl->format->Bshift, sdl->flags);
	fprintf(stderr, "Video mode : %dx%d %d bits/pixel %d bytes/pixel [R<<%d G<<%d B<<%d] flags=%x\n", sdl->w, sdl->h, sdl->format->BitsPerPixel, sdl->format->BytesPerPixel, sdl->format->Rshift, sdl->format->Gshift, sdl->format->Bshift, sdl->flags);

	srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl;

	return srf;
}

JiveSurface *jive_surface_newRGB(Uint16 w, Uint16 h) {
	JiveSurface *srf;
	SDL_Surface *screen, *sdl;
	int bpp;

	screen = SDL_GetVideoSurface();
	bpp = screen->format->BitsPerPixel;

	sdl = SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, bpp, 0, 0, 0, 0);

	/* Opaque surface */
	SDL_SetAlpha(sdl, SDL_SRCALPHA, SDL_ALPHA_OPAQUE);

	srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl;

	return srf;
}

SDL_Surface *surface_newRGBA(Uint16 w, Uint16 h) {
	SDL_Surface *sdl;

	/*
	 * Work out the optimium pixel masks for the display with
	 * 32 bit alpha surfaces. If we get this wrong a non-optimised
	 * blitter will be used.
	 */
	const SDL_VideoInfo *video_info = SDL_GetVideoInfo();
	if (video_info->vfmt->Rmask < video_info->vfmt->Bmask) {
		sdl = SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, 32,
					   0x000000FF, 0x0000FF00, 0x00FF0000, 0xFF000000);
	}
	else {
		sdl = SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, 32,
					   0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000);
	}

	/* alpha channel, paint transparency */
	SDL_SetAlpha(sdl, SDL_SRCALPHA, SDL_ALPHA_OPAQUE);
	return sdl;
}


JiveSurface *jive_surface_newRGBA(Uint16 w, Uint16 h) {
	JiveSurface *srf;

	SDL_Surface *sdl = surface_newRGBA(w,h);
	srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl;

	return srf;
}


JiveSurface *jive_surface_new_SDLSurface(SDL_Surface *sdl_surface) {
	JiveSurface *srf;

	srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl_surface;

	return srf;
}


JiveSurface *jive_surface_ref(JiveSurface *srf) {
	return jive_tile_ref(srf);
}


/*
 * Convert image to best format for display on the screen
 */
static JiveSurface *jive_surface_display_format(JiveSurface *srf) {
	SDL_Surface *sdl;

	if (srf->sdl == NULL || SDL_GetVideoSurface() == NULL) {
		return srf;
	}

	if (srf->sdl->format->Amask) {
		sdl = SDL_DisplayFormatAlpha(srf->sdl);
	}
	else {
		sdl = SDL_DisplayFormat(srf->sdl);
	}
	SDL_FreeSurface(srf->sdl);
	srf->sdl = sdl;

	return srf;
}


JiveSurface *jive_surface_load_image(const char *path) {
	return jive_tile_load_image(path);
}

JiveSurface *jive_surface_alt_load_image(const char *path) {
	SDL_Surface *sdl = IMG_Load(path);

	JiveSurface *srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl;

	return jive_surface_display_format(srf);
}


JiveSurface *jive_surface_load_image_data(const char *data, size_t len) {
	SDL_RWops *src = SDL_RWFromConstMem(data, (int) len);
	SDL_Surface *sdl = IMG_Load_RW(src, 1);

	JiveSurface *srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl;

	return jive_surface_display_format(srf);
}


int jive_surface_set_wm_icon(JiveSurface *srf) {
	SDL_WM_SetIcon(_resolve_SDL_surface(srf), NULL);
	return 1;
}


int jive_surface_save_bmp(JiveSurface *srf, const char *file) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return 0;
	}
	return SDL_SaveBMP(srf->sdl, file);
}

int save_png(SDL_Surface * sdl, const char* file) {
	if (sdl->format->BitsPerPixel <= 24 || sdl->format->Amask) {
		LOG_INFO(log_ui_draw, "SavePng: PNG Format Alpha not required");
		return SDL_SavePNG(sdl, file);
	} else {
		LOG_INFO(log_ui_draw, "SavePng: PNG Format Alpha");
		SDL_Surface *spfa = SDL_PNGFormatAlpha(sdl);
		int rv = SDL_SavePNG(spfa, file);
		SDL_FreeSurface(spfa);
		return rv;
	}
}

int jive_surface_save_png(JiveSurface *srf, const char *file) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return 0;
	}
	return save_png(srf->sdl, file);
}


static int _getPixel(SDL_Surface *s, Uint16 x, Uint16 y) {
	Uint8 R, G, B;

	switch (s->format->BytesPerPixel) {
	case 1: { /* 8-bpp */
		Uint8 *p;
		p = (Uint8 *)s->pixels + y*s->pitch + x;

		SDL_GetRGB(*p, s->format, &R, &G, &B);
		return (R << 16) | (G << 8) | B;
	}

	case 2: { /* 15-bpp or 16-bpp */
		Uint16 *p;
		p = (Uint16 *)s->pixels + y*s->pitch/2 + x;

		SDL_GetRGB(*p, s->format, &R, &G, &B);
		return (R << 16) | (G << 8) | B;
	}

	case 3: { /* 24-bpp */
		/* FIXME */
		assert(0);
	}

	case 4: { /* 32-bpp */
		Uint32 *p;
		p = (Uint32 *)s->pixels + y*s->pitch/4 + x;

		SDL_GetRGB(*p, s->format, &R, &G, &B);
		return (R << 16) | (G << 8) | B;
	}
	}

	return 0;
}


int jive_surface_cmp(JiveSurface *a, JiveSurface *b, Uint32 key) {
	SDL_Surface *sa = _resolve_SDL_surface(a);
	SDL_Surface *sb = _resolve_SDL_surface(b);
	Uint32 pa, pb;
	int x, y;
	int count=0, equal=0;

	if (!sa || !sb) {
		return 0;
	}

	if (sa->w != sb->w || sa->h != sb->h) {
		return 0;
	}

	if (SDL_MUSTLOCK(sa)) {
		SDL_LockSurface(sa);
	}
	if (SDL_MUSTLOCK(sb)) {
		SDL_LockSurface(sb);
	}
	
	for (x=0; x<sa->w; x++) {
		for (y=0; y<sa->h; y++) {
			pa = _getPixel(sa, x, y);
			pb = _getPixel(sb, x ,y);
			
			count++;
			if (pa == pb || pa == key || pb == key) {
				equal++;
			}
		}
	}

	if (SDL_MUSTLOCK(sb)) {
		SDL_UnlockSurface(sb);
	}
	if (SDL_MUSTLOCK(sa)) {
		SDL_UnlockSurface(sa);
	}

	return (int)(((float)equal / count) * 100);
}

void jive_surface_get_offset(JiveSurface *srf, Sint16 *x, Sint16 *y) {
	*x = srf->offset_x;
	*y = srf->offset_y;
}

void jive_surface_set_offset(JiveSurface *srf, Sint16 x, Sint16 y) {
	srf->offset_x = x;
	srf->offset_y = y;
}

void jive_surface_get_clip(JiveSurface *srf, SDL_Rect *r) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	SDL_GetClipRect(srf->sdl, r);

	r->x -= srf->offset_x;
	r->y -= srf->offset_y;
}

void jive_surface_set_clip(JiveSurface *srf, SDL_Rect *r) {
	SDL_Rect tmp;
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}

	if (r) {
		tmp.x = r->x + srf->offset_x;
		tmp.y = r->y + srf->offset_y;
		tmp.w = r->w;
		tmp.h = r->h;
	}
	else {
		tmp.x = 0;
		tmp.y = 0;
		tmp.w = srf->sdl->w;
		tmp.h = srf->sdl->h;
	}

	SDL_SetClipRect(srf->sdl, &tmp);
}


void jive_surface_push_clip(JiveSurface *srf, SDL_Rect *r, SDL_Rect *pop)
{
	SDL_Rect tmp;

	jive_surface_get_clip(srf, pop);
	jive_rect_intersection(r, pop, &tmp);
	jive_surface_set_clip(srf, &tmp);
}


void jive_surface_set_clip_arg(JiveSurface *srf, Uint16 x, Uint16 y, Uint16 w, Uint16 h) {
	SDL_Rect tmp;
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}

	tmp.x = x + srf->offset_x;
	tmp.y = y + srf->offset_y;
	tmp.w = w;
	tmp.h = h;

	SDL_SetClipRect(srf->sdl, &tmp);
}

void jive_surface_get_clip_arg(JiveSurface *srf, Uint16 *x, Uint16 *y, Uint16 *w, Uint16 *h) {
	SDL_Rect tmp;
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		*x = 0;
		*y = 0;
		*w = 0;
		*h = 0;
		return;
	}

	SDL_GetClipRect(srf->sdl, &tmp);

	*x = tmp.x - srf->offset_x;
	*y = tmp.y - srf->offset_y;
	*w = tmp.w;
	*h = tmp.h;
}

void jive_surface_flip(JiveSurface *srf) {
	SDL_Flip(srf->sdl);
}


void jive_surface_blit(JiveSurface *src, JiveSurface *dst, Uint16 dx, Uint16 dy) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT

	SDL_Rect dr;
	dr.x = dx + dst->offset_x;
	dr.y = dy + dst->offset_y;

	SDL_BlitSurface(_resolve_SDL_surface(src), 0, dst->sdl, &dr);

#ifdef JIVE_PROFILE_BLIT
	t1 = jive_jiffies();
	printf("\tjive_surface_blit took=%d\n", t1-t0);
#endif //JIVE_PROFILE_BLIT
}


void jive_surface_blit_clip(JiveSurface *src, Uint16 sx, Uint16 sy, Uint16 sw, Uint16 sh,
			  JiveSurface* dst, Uint16 dx, Uint16 dy) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT

	SDL_Rect sr, dr;
	sr.x = sx; sr.y = sy; sr.w = sw; sr.h = sh;
	dr.x = dx + dst->offset_x; dr.y = dy + dst->offset_y;

	SDL_BlitSurface(_resolve_SDL_surface(src), &sr, dst->sdl, &dr);

#ifdef JIVE_PROFILE_BLIT
	t1 = jive_jiffies();
	printf("\tjive_surface_blit took=%d\n", t1-t0);
#endif //JIVE_PROFILE_BLIT
}


void jive_surface_blit_alpha(JiveSurface *src, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint8 alpha) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT

	SDL_Rect dr;
	dr.x = dx + dst->offset_x;
	dr.y = dy + dst->offset_y;

	SDL_SetAlpha(_resolve_SDL_surface(src), SDL_SRCALPHA, alpha);
	SDL_BlitSurface(_resolve_SDL_surface(src), 0, dst->sdl, &dr);

#ifdef JIVE_PROFILE_BLIT
	t1 = jive_jiffies();
	printf("\tjive_surface_blit took=%d\n", t1-t0);
#endif //JIVE_PROFILE_BLIT
}


void jive_surface_get_size(JiveSurface *srf, Uint16 *w, Uint16 *h) {
	if (IS_DYNAMIC_IMAGE(srf)) {
		jive_tile_get_min_size(srf, w, h);
		return;
	}

	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		if (w)
			*w = 0;
		if (h)
			*h = 0;
		return;
	}
	if (w) {
		*w = srf->sdl->w;
	}
	if (h) {
		*h = srf->sdl->h;
	}
}


int jive_surface_get_bytes(JiveSurface *srf) {
	SDL_PixelFormat *format;


	if (!srf->sdl) {
		return 0;
	}

	format = srf->sdl->format;
	return srf->sdl->w * srf->sdl->h * format->BytesPerPixel;
}


void jive_surface_free(JiveSurface *srf) {
	jive_tile_free(srf);
	return;
}


void jive_surface_release(JiveSurface *srf) {
	if (IS_DYNAMIC_IMAGE(srf)) {
		LOG_ERROR(log_ui, "jive_surface_release called for JiveTile");
		return;
	}

	if (srf->sdl) {
		LOG_INFO(log_ui, "jive_surface_release OK");
		SDL_FreeSurface (srf->sdl);
		srf->sdl = NULL;
	}
}

/* SDL_gfx encapsulated functions */
JiveSurface *jive_surface_rotozoomSurface(JiveSurface *srf, double angle, double zoom, int smooth){
	SDL_Surface *srf1_sdl;
	JiveSurface *srf2;

	srf1_sdl = _resolve_SDL_surface(srf);

	if (!srf1_sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return NULL;
	}

	srf2 = calloc(sizeof(JiveSurface), 1);
	srf2->refcount = 1;
	srf2->sdl = rotozoomSurface(srf1_sdl, angle, zoom, smooth);

	return srf2;
}

JiveSurface *jive_surface_zoomSurface(JiveSurface *srf, double zoomx, double zoomy, int smooth) {
	SDL_Surface *srf1_sdl;
	JiveSurface *srf2;

	srf1_sdl = _resolve_SDL_surface(srf);

	if (!srf1_sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return NULL;
	}

	srf2 = calloc(sizeof(JiveSurface), 1);
	srf2->refcount = 1;
	srf2->sdl = zoomSurface(srf1_sdl, zoomx, zoomy, smooth);

	return srf2;
}

JiveSurface *jive_surface_shrinkSurface(JiveSurface *srf, int factorx, int factory) {
	SDL_Surface *srf1_sdl;
	JiveSurface *srf2;

	srf1_sdl = _resolve_SDL_surface(srf);

	if (!srf1_sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return NULL;
	}

	srf2 = calloc(sizeof(JiveSurface), 1);
	srf2->refcount = 1;
	srf2->sdl = shrinkSurface(srf1_sdl, factorx, factory);

	return srf2;
}

JiveSurface *jive_surface_resize(JiveSurface *srf, int w, int h, bool keep_aspect) {
	SDL_Surface *srf1_sdl;
	JiveSurface *srf2;
	int sw, sh, dw, dh;
	int ox = 0, oy = 0;

	srf1_sdl = _resolve_SDL_surface(srf);

	if (!srf1_sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return NULL;
	}

	sw = srf1_sdl->w;
	sh = srf1_sdl->h;

	srf2 = jive_surface_newRGBA(w, h);

	if (keep_aspect) {
		float w_aspect = (float)w/(float)sw;
		float h_aspect = (float)h/(float)sh;
		if (w_aspect <= h_aspect) {
			dw = w;
			dh = sh * w_aspect;
			oy = (h - dh)/2;
		} else {
			dh = h;
			dw = sw * h_aspect;
			ox = (w - dw)/2;
		}
	} else {
		dh = h;
		dw = w;
	}

	LOG_DEBUG(log_ui, "Resize ox: %d oy: %d dw: %d dh: %d sw: %d sh: %d", ox, oy, dw, dh, sw, sh);

	copyResampled(srf2->sdl, srf1_sdl, ox, oy, 0, 0, dw, dh, sw, sh);

	return srf2;
}

void jive_surface_pixelColor(JiveSurface *srf, Sint16 x, Sint16 y, Uint32 color) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	pixelColor(srf->sdl,
		   x + srf->offset_x,
		   y + srf->offset_y,
		   color);
}

void jive_surface_hlineColor(JiveSurface *srf, Sint16 x1, Sint16 x2, Sint16 y, Uint32 color) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	hlineColor(srf->sdl,
		   x1 + srf->offset_x,
		   x2 + srf->offset_x,
		   y + srf->offset_y,
		   color);
}

void jive_surface_vlineColor(JiveSurface *srf, Sint16 x, Sint16 y1, Sint16 y2, Uint32 color) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	vlineColor(srf->sdl,
		   x + srf->offset_x,
		   y1 + srf->offset_y,
		   y2 + srf->offset_y,
		   color);
}

void jive_surface_rectangleColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	rectangleColor(srf->sdl,
		       x1 + srf->offset_x,
		       y1 + srf->offset_y,
		       x2 + srf->offset_x,
		       y2 + srf->offset_y,
		       col);
}

void jive_surface_boxColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	boxColor(srf->sdl,
		 x1 + srf->offset_x,
		 y1 + srf->offset_y,
		 x2 + srf->offset_x,
		 y2 + srf->offset_y,
		 col);
}

void jive_surface_lineColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	lineColor(srf->sdl,
		  x1 + srf->offset_x,
		  y1 + srf->offset_y,
		  x2 + srf->offset_x,
		  y2 + srf->offset_y,
		  col);
}

void jive_surface_aalineColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	aalineColor(srf->sdl,
		    x1 + srf->offset_x,
		    y1 + srf->offset_y,
		    x2 + srf->offset_x,
		    y2 + srf->offset_y,
		    col);
}

void jive_surface_circleColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 r, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	circleColor(srf->sdl,
		    x + srf->offset_x,
		    y + srf->offset_y,
		    r,
		    col);
}

void jive_surface_aacircleColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 r, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	aacircleColor(srf->sdl,
		      x + srf->offset_x,
		      y + srf->offset_y,
		      r,
		      col);
}

void jive_surface_filledCircleColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 r, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	filledCircleColor(srf->sdl,
			  x + srf->offset_x,
			  y + srf->offset_y,
			  r,
			  col);
}

void jive_surface_ellipseColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	ellipseColor(srf->sdl,
		     x + srf->offset_x,
		     y + srf->offset_y,
		     rx,
		     ry,
		     col);
}

void jive_surface_aaellipseColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	aaellipseColor(srf->sdl,
		       x + srf->offset_x,
		       y + srf->offset_y,
		       rx,
		       ry,
		       col);
}

void jive_surface_filledEllipseColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	filledEllipseColor(srf->sdl,
			   x + srf->offset_x,
			   y + srf->offset_y,
			   rx,
			   ry,
			   col);
}

void jive_surface_pieColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rad, Sint16 start, Sint16 end, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	pieColor(srf->sdl,
		 x + srf->offset_x,
		 y + srf->offset_y,
		 rad,
		 start,
		 end,
		 col);
}

void jive_surface_filledPieColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rad, Sint16 start, Sint16 end, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	filledPieColor(srf->sdl,
		       x + srf->offset_x,
		       y + srf->offset_y,
		       rad,
		       start,
		       end,
		       col);
}

void jive_surface_trigonColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	trigonColor(srf->sdl,
		    x1 + srf->offset_x,
		    y1 + srf->offset_y,
		    x2 + srf->offset_x,
		    y2 + srf->offset_y,
		    x3 + srf->offset_x,
		    y3 + srf->offset_y,
		    col);
}

void jive_surface_aatrigonColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	aatrigonColor(srf->sdl,
		      x1 + srf->offset_x,
		      y1 + srf->offset_y,
		      x2 + srf->offset_x,
		      y2 + srf->offset_y,
		      x3 + srf->offset_x,
		      y3 + srf->offset_y,
		      col);
}

void jive_surface_filledTrigonColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	filledTrigonColor(srf->sdl,
			  x1 + srf->offset_x,
			  y1 + srf->offset_y,
			  x2 + srf->offset_x,
			  y2 + srf->offset_y,
			  x3 + srf->offset_x,
			  y3 + srf->offset_y,
			  col);
}

// Lua bindings

int jiveL_surface_newRGB(lua_State *L) {
	/*
	  class
	  width
	  height
	*/
	int width = luaL_checkint(L, 2);
	int height= luaL_checkint(L, 3);

	if (width && height) {
		JiveSurface *srf = jive_surface_newRGB(width, height);
		if (srf) {
			JiveSurface **p = (JiveSurface **)lua_newuserdata(L, sizeof(JiveSurface *));
			*p = srf;
			luaL_getmetatable(L, "JiveSurface");
			lua_setmetatable(L, -2);
			return 1;
		}
	}

	return 0;
}

int jiveL_surface_newRGBA(lua_State *L) {
	/*
	  class
	  width
	  height
	*/
	int width = luaL_checkint(L, 2);
	int height= luaL_checkint(L, 3);

	if (width && height) {
		JiveSurface *srf = jive_surface_newRGBA(width, height);
		if (srf) {
			JiveSurface **p = (JiveSurface **)lua_newuserdata(L, sizeof(JiveSurface *));
			*p = srf;
			luaL_getmetatable(L, "JiveSurface");
			lua_setmetatable(L, -2);
			return 1;
		}
	}

	return 0;
}

int jiveL_surface_load_image(lua_State *L) {
	/*
	  class
	  imagepath
	*/
	const char *imagepath = luaL_checklstring(L, 2, NULL);
	if (imagepath) {
		JiveSurface *srf = jive_surface_load_image(imagepath);
		if (srf) {
			JiveSurface **p = (JiveSurface **)lua_newuserdata(L, sizeof(JiveSurface *));
			*p = srf;
			luaL_getmetatable(L, "JiveSurface");
			lua_setmetatable(L, -2);
			return 1;
		}
	}

	return 0;
}

int jiveL_surface_alt_load_image(lua_State *L) {
	/*
	  class
	  imagepath
	*/
	const char *imagepath = luaL_checklstring(L, 2, NULL);
	if (imagepath) {
		JiveSurface *srf = jive_surface_alt_load_image(imagepath);
		if (srf) {
			JiveSurface **p = (JiveSurface **)lua_newuserdata(L, sizeof(JiveSurface *));
			*p = srf;
			luaL_getmetatable(L, "JiveSurface");
			lua_setmetatable(L, -2);
			return 1;
		}
	}

	return 0;
}


int jiveL_surface_load_image_data(lua_State *L) {
	/*
	  class
	  image
	  len
	*/
	const char *image = luaL_checklstring(L, 2, NULL);
	int len = luaL_checkint(L, 3);
	if (image && len) {
		JiveSurface *srf = jive_surface_load_image_data(image, len);
		if (srf) {
			JiveSurface **p = (JiveSurface **)lua_newuserdata(L, sizeof(JiveSurface *));
			*p = srf;
			luaL_getmetatable(L, "JiveSurface");
			lua_setmetatable(L, -2);
			return 1;
		}
	}

	return 0;
}

int jiveL_surface_draw_text(lua_State *L) {
	/*
	  class
	  font
	  color
	  string
	*/
	JiveFont *font = *(JiveFont **)lua_touserdata(L, 2);
	int color = luaL_checkint(L, 3);
	const char *string = luaL_checklstring(L, 4, NULL);
	if (font && string) {
		JiveSurface *srf = jive_font_draw_text(font, color, string);
		if (srf) {
			JiveSurface **p = (JiveSurface **)lua_newuserdata(L, sizeof(JiveSurface *));
			*p = srf;
			luaL_getmetatable(L, "JiveSurface");
			lua_setmetatable(L, -2);
			return 1;
		}
	}

	return 0;
}

int jiveL_surface_free(lua_State *L) {
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	if (srf) {
		jive_surface_free(srf);
	}
	return 0;
}

int jiveL_surface_alt_release(lua_State *L) {
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);

	if (srf) {
		if (srf->sdl) {
			LOG_INFO(log_ui, "jive_surface_release OK");
			SDL_FreeSurface (srf->sdl);
			srf->sdl = NULL;
		}
//		free(srf);
	}
	return 0;
}

int jiveL_surface_release(lua_State *L) {
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	if (srf) {
		jive_surface_release(srf);
	}
	return 0;
}

int jiveL_surface_save_bmp(lua_State *L) {
	/*
	  surface
	  filename
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	const char *image = luaL_checklstring(L, 2, NULL);
	if (srf && image) {
		lua_pushinteger(L, jive_surface_save_bmp(srf, image));
		return 1;
	}
	return 0;
}

int jiveL_surface_save_png(lua_State *L) {
	/*
	  surface
	  filename
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	const char *image = luaL_checklstring(L, 2, NULL);
	if (srf && image) {
		lua_pushinteger(L, jive_surface_save_png(srf, image));
		return 1;
	}
	return 0;
}


int jiveL_surface_cmp(lua_State *L) {
	/*
	  surface A
	  surface B
	  key
	*/
	JiveSurface *srfA = *(JiveSurface **)lua_touserdata(L, 1);
	JiveSurface *srfB = *(JiveSurface **)lua_touserdata(L, 2);
	int key = luaL_checkint(L, 3);
	if (srfA && srfB) {
		lua_pushinteger(L, jive_surface_cmp(srfA, srfB, key));
		return 1;
	}
	return 0;
}

int jiveL_surface_set_offset(lua_State *L) {
	/*
	  surface
	  x
	  y
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	if (srf) {
		jive_surface_set_offset(srf, x, y);
	}
	return 0;
}

int jiveL_surface_set_clip_arg(lua_State *L) {
	/*
	  surface
	  x
	  y
	  w
	  h
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	int w = luaL_checkint(L, 4);
	int h = luaL_checkint(L, 5);
	if (srf) {
		jive_surface_set_clip_arg(srf, x, y, w, h);
	}
	return 0;
}

int jiveL_surface_get_clip_arg(lua_State *L) {
	/*
	  surface
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	Uint16 x, y, w, h;
	if (srf) {
		jive_surface_get_clip_arg(srf, &x, &y, &w, &h);
		lua_pushinteger(L, x);
		lua_pushinteger(L, y);
		lua_pushinteger(L, w);
		lua_pushinteger(L, h);
		return 4;
	}
	return 0;
}

int jiveL_surface_blit(lua_State *L) {
	/*
	  surface src
	  surface ds
	  dx
	  dy
	*/
	JiveSurface *src = *(JiveSurface **)lua_touserdata(L, 1);
	JiveSurface *dst = *(JiveSurface **)lua_touserdata(L, 2);
	int dx = luaL_checkint(L, 3);
	int dy = luaL_checkint(L, 4);
	if (src && dst) {
		jive_surface_blit(src, dst, dx, dy);
	}
	return 0;
}

int jiveL_surface_blit_clip(lua_State *L) {
	/*
	  surface src
	  sx
	  sy
	  sw
	  sh
	  surface dst
	  dx
	  dy
	*/
	JiveSurface *src = *(JiveSurface **)lua_touserdata(L, 1);
	int sx = luaL_checkint(L, 2);
	int sy = luaL_checkint(L, 3);
	int sw = luaL_checkint(L, 4);
	int sh = luaL_checkint(L, 5);
	JiveSurface *dst = *(JiveSurface **)lua_touserdata(L, 6);
	int dx = luaL_checkint(L, 7);
	int dy = luaL_checkint(L, 8);
	if (src && dst) {
		jive_surface_blit_clip(src, sx, sy, sw, sh, dst, dx, dy);
	}
	return 0;
}

int jiveL_surface_blit_alpha(lua_State *L) {
	/*
	  surface src
	  surface ds
	  dx
	  dy
	  alpha
	*/
	JiveSurface *src = *(JiveSurface **)lua_touserdata(L, 1);
	JiveSurface *dst = *(JiveSurface **)lua_touserdata(L, 2);
	int dx = luaL_checkint(L, 3);
	int dy = luaL_checkint(L, 4);
	int alpha = luaL_checkint(L, 5);
	if (src && dst) {
		jive_surface_blit_alpha(src, dst, dx, dy, alpha);
	}
	return 0;
}

int jiveL_surface_get_size(lua_State *L) {
	/*
	  surface
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	Uint16 w, h;
	if (srf) {
		jive_surface_get_size(srf, &w, &h);
		lua_pushinteger(L, w);
		lua_pushinteger(L, h);
		return 2;
	}
	return 0;
}

int jiveL_surface_get_bytes(lua_State *L) {
	/*
	  surface
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	if (srf) {
		lua_pushinteger(L, jive_surface_get_bytes(srf));
		return 1;
	}
	return 0;
}

int jiveL_surface_rotozoomSurface(lua_State *L) {
	/*
	  surface
	  angle
	  zoom
	  smooth
	*/
	JiveSurface *srf1 = *(JiveSurface **)lua_touserdata(L, 1);
	double angle = luaL_checknumber(L, 2);
	double zoom  = luaL_checknumber(L, 3);
	int smooth = lua_isnumber(L, 4) ? luaL_checkint(L, 4) : 1;

	JiveSurface *srf2 = jive_surface_rotozoomSurface(srf1, angle, zoom, smooth);
	if (srf2) {
		JiveSurface **p = (JiveSurface **)lua_newuserdata(L, sizeof(JiveSurface *));
		*p = srf2;
		luaL_getmetatable(L, "JiveSurface");
		lua_setmetatable(L, -2);
		return 1;
	}

	return 0;
}

int jiveL_surface_zoomSurface(lua_State *L) {
	/*
	  surface
	  zoomx
	  zoomy
	  smooth
	*/
	JiveSurface *srf1 = *(JiveSurface **)lua_touserdata(L, 1);
	double zoomx = luaL_checknumber(L, 2);
	double zoomy  = luaL_checknumber(L, 3);
	int smooth = lua_isnumber(L, 4) ? luaL_checkint(L, 4) : 1;

	JiveSurface *srf2 = jive_surface_zoomSurface(srf1, zoomx, zoomy, smooth);
	if (srf2) {
		JiveSurface **p = (JiveSurface **)lua_newuserdata(L, sizeof(JiveSurface *));
		*p = srf2;
		luaL_getmetatable(L, "JiveSurface");
		lua_setmetatable(L, -2);
		return 1;
	}

	return 0;
}

int jiveL_surface_shrinkSurface(lua_State *L) {
	/*
	  surface
	  factorx
	  factory
	*/
	JiveSurface *srf1 = *(JiveSurface **)lua_touserdata(L, 1);
	int factorx = luaL_checkint(L, 2);
	int factory = luaL_checkint(L, 3);

	JiveSurface *srf2 = jive_surface_shrinkSurface(srf1, factorx, factory);
	if (srf2) {
		JiveSurface **p = (JiveSurface **)lua_newuserdata(L, sizeof(JiveSurface *));
		*p = srf2;
		luaL_getmetatable(L, "JiveSurface");
		lua_setmetatable(L, -2);
		return 1;
	}

	return 0;
}

int jiveL_surface_resize(lua_State *L) {
	/*
	  surface
	  w
	  h
	*/
	JiveSurface *srf1 = *(JiveSurface **)lua_touserdata(L, 1);
	int w = luaL_checkint(L, 2);
	int h = luaL_checkint(L, 3);
	bool keep_aspect = lua_toboolean(L, 4);

	JiveSurface *srf2 = jive_surface_resize(srf1, w, h, keep_aspect);
	if (srf2) {
		JiveSurface **p = (JiveSurface **)lua_newuserdata(L, sizeof(JiveSurface *));
		*p = srf2;
		luaL_getmetatable(L, "JiveSurface");
		lua_setmetatable(L, -2);
		return 1;
	}

	return 0;
}

int jiveL_surface_pixelColor(lua_State *L) {
	/*
	  surface
	  x
	  y
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	int color = luaL_checkint(L, 4);

	jive_surface_pixelColor(srf, x, y, color);

	return 0;
}

int jiveL_surface_hlineColor(lua_State *L) {
	/*
	  surface
	  x1
	  x2
	  y
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x1 = luaL_checkint(L, 2);
	int x2 = luaL_checkint(L, 3);
	int y  = luaL_checkint(L, 4);
	int color = luaL_checkint(L, 5);

	jive_surface_hlineColor(srf, x1, x2, y, color);

	return 0;
}

int jiveL_surface_vlineColor(lua_State *L) {
	/*
	  surface
	  x
	  y1
	  y2
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y1 = luaL_checkint(L, 3);
	int y2 = luaL_checkint(L, 4);
	int color = luaL_checkint(L, 5);

	jive_surface_vlineColor(srf, x, y1, y2, color);

	return 0;
}

int jiveL_surface_rectangleColor(lua_State *L) {
	/*
	  surface
	  x1
	  y1
	  x2
	  y2
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x1 = luaL_checkint(L, 2);
	int y1 = luaL_checkint(L, 3);
	int x2 = luaL_checkint(L, 4);
	int y2 = luaL_checkint(L, 5);
	int color = luaL_checkint(L, 6);

	jive_surface_rectangleColor(srf, x1, y1, x2, y2, color);

	return 0;
}

int jiveL_surface_boxColor(lua_State *L) {
	/*
	  surface
	  x1
	  y1
	  x2
	  y2
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x1 = luaL_checkint(L, 2);
	int y1 = luaL_checkint(L, 3);
	int x2 = luaL_checkint(L, 4);
	int y2 = luaL_checkint(L, 5);
	int color = luaL_checkint(L, 6);

	jive_surface_boxColor(srf, x1, y1, x2, y2, color);

	return 0;
}

int jiveL_surface_lineColor(lua_State *L) {
	/*
	  surface
	  x1
	  y1
	  x2
	  y2
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x1 = luaL_checkint(L, 2);
	int x2 = luaL_checkint(L, 3);
	int y1 = luaL_checkint(L, 4);
	int y2 = luaL_checkint(L, 5);
	int color = luaL_checkint(L, 6);

	jive_surface_lineColor(srf, x1, y1, x2, y2, color);

	return 0;
}

int jiveL_surface_aalineColor(lua_State *L) {
	/*
	  surface
	  x1
	  y1
	  x2
	  y2
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x1 = luaL_checkint(L, 2);
	int x2 = luaL_checkint(L, 3);
	int y1 = luaL_checkint(L, 4);
	int y2 = luaL_checkint(L, 5);
	int color = luaL_checkint(L, 6);

	jive_surface_aalineColor(srf, x1, y1, x2, y2, color);

	return 0;
}

int jiveL_surface_circleColor(lua_State *L) {
	/*
	  surface
	  x
	  y
	  r
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	int r = luaL_checkint(L, 4);
	int color = luaL_checkint(L, 5);

	jive_surface_aacircleColor(srf, x, y, r, color);

	return 0;
}

int jiveL_surface_aacircleColor(lua_State *L) {
	/*
	  surface
	  x
	  y
	  r
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	int r = luaL_checkint(L, 4);
	int color = luaL_checkint(L, 5);

	jive_surface_aacircleColor(srf, x, y, r, color);

	return 0;
}

int jiveL_surface_filledCircleColor(lua_State *L) {
	/*
	  surface
	  x
	  y
	  r
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	int r = luaL_checkint(L, 4);
	int color = luaL_checkint(L, 5);

	jive_surface_filledCircleColor(srf, x, y, r, color);

	return 0;
}

int jiveL_surface_ellipseColor(lua_State *L) {
	/*
	  surface
	  x
	  y
	  rx
	  ry
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	int rx = luaL_checkint(L, 4);
	int ry = luaL_checkint(L, 5);
	int color = luaL_checkint(L, 6);

	jive_surface_ellipseColor(srf, x, y, rx, ry, color);

	return 0;
}

int jiveL_surface_aaellipseColor(lua_State *L) {
	/*
	  surface
	  x
	  y
	  rx
	  ry
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	int rx = luaL_checkint(L, 4);
	int ry = luaL_checkint(L, 5);
	int color = luaL_checkint(L, 6);

	jive_surface_aaellipseColor(srf, x, y, rx, ry, color);

	return 0;
}

int jiveL_surface_filledEllipseColor(lua_State *L) {
	/*
	  surface
	  x
	  y
	  rx
	  ry
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	int rx = luaL_checkint(L, 4);
	int ry = luaL_checkint(L, 5);
	int color = luaL_checkint(L, 6);

	jive_surface_filledEllipseColor(srf, x, y, rx, ry, color);

	return 0;
}

int jiveL_surface_pieColor(lua_State *L) {
	/*
	  surface
	  x
	  y
	  rad
	  start
	  end
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	int rad = luaL_checkint(L, 4);
	int start = luaL_checkint(L, 5);
	int end = luaL_checkint(L, 6);
	int color = luaL_checkint(L, 7);

	jive_surface_pieColor(srf, x, y, rad, start, end, color);

	return 0;
}

int jiveL_surface_filledPieColor(lua_State *L) {
	/*
	  surface
	  x
	  y
	  rad
	  start
	  end
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x = luaL_checkint(L, 2);
	int y = luaL_checkint(L, 3);
	int rad = luaL_checkint(L, 4);
	int start = luaL_checkint(L, 5);
	int end = luaL_checkint(L, 6);
	int color = luaL_checkint(L, 7);

	jive_surface_pieColor(srf, x, y, rad, start, end, color);

	return 0;
}

int jiveL_surface_trigonColor(lua_State *L) {
	/*
	  surface
	  x1
	  y1
	  x2
	  y2
	  x3
	  y3
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x1 = luaL_checkint(L, 2);
	int y1 = luaL_checkint(L, 3);
	int x2 = luaL_checkint(L, 4);
	int y2 = luaL_checkint(L, 5);
	int x3 = luaL_checkint(L, 6);
	int y3 = luaL_checkint(L, 7);
	int color = luaL_checkint(L, 8);

	jive_surface_trigonColor(srf, x1, y1, x2, y2, x3, y3, color);

	return 0;
}

int jiveL_surface_aatrigonColor(lua_State *L) {
	/*
	  surface
	  x1
	  y1
	  x2
	  y2
	  x3
	  y3
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x1 = luaL_checkint(L, 2);
	int y1 = luaL_checkint(L, 3);
	int x2 = luaL_checkint(L, 4);
	int y2 = luaL_checkint(L, 5);
	int x3 = luaL_checkint(L, 6);
	int y3 = luaL_checkint(L, 7);
	int color = luaL_checkint(L, 8);

	jive_surface_aatrigonColor(srf, x1, y1, x2, y2, x3, y3, color);

	return 0;
}

int jiveL_surface_filledTrigonColor(lua_State *L) {
	/*
	  surface
	  x1
	  y1
	  x2
	  y2
	  x3
	  y3
	  color
	*/
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 1);
	int x1 = luaL_checkint(L, 2);
	int y1 = luaL_checkint(L, 3);
	int x2 = luaL_checkint(L, 4);
	int y2 = luaL_checkint(L, 5);
	int x3 = luaL_checkint(L, 6);
	int y3 = luaL_checkint(L, 7);
	int color = luaL_checkint(L, 8);

	jive_surface_filledTrigonColor(srf, x1, y1, x2, y2, x3, y3, color);

	return 0;
}

int jiveL_tile_fill_color(lua_State *L) {
	/*
	  class
	  color
	*/
	int color = luaL_checkint(L, 2);
	JiveTile *tile = jive_tile_fill_color(color);
	JiveTile **p = (JiveTile **)lua_newuserdata(L, sizeof(JiveTile *));
	*p = tile;
	luaL_getmetatable(L, "JiveTile");
	lua_setmetatable(L, -2);
	return 1;
}

int jiveL_tile_load_image(lua_State *L) {
	/*
	  class
	  path
	*/
	const char *path = luaL_checkstring(L, 2);
	JiveTile *tile = jive_tile_load_image(path);
	JiveTile **p = (JiveTile **)lua_newuserdata(L, sizeof(JiveTile *));
	*p = tile;
	luaL_getmetatable(L, "JiveTile");
	lua_setmetatable(L, -2);
	return 1;
}

int jiveL_tile_load_tiles(lua_State *L) {
	JiveTile *tile;
	JiveTile **p;
	/*
	  class
	  path table [9 entries]
	*/
	const char *paths[9];
	lua_rawgeti(L, 2, 1);
	paths[0] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 2);
	paths[1] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 3);
	paths[2] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 4);
	paths[3] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 5);
	paths[4] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 6);
	paths[5] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 7);
	paths[6] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 8);
	paths[7] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 9);
	paths[8] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	tile = jive_tile_load_tiles((char **)paths);
	lua_pop(L, 9);
	p = (JiveTile **)lua_newuserdata(L, sizeof(JiveTile *));
	*p = tile;
	luaL_getmetatable(L, "JiveTile");
	lua_setmetatable(L, -2);
	return 1;
}

int jiveL_tile_load_vtiles(lua_State *L) {
	JiveTile *tile;
	JiveTile **p;

	/*
	  class
	  path table [3 entries]
	*/
	const char *paths[3];
	lua_rawgeti(L, 2, 1);
	paths[0] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 2);
	paths[1] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 3);
	paths[2] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	tile = jive_tile_load_vtiles((char **)paths);
	lua_pop(L, 3);
	p = (JiveTile **)lua_newuserdata(L, sizeof(JiveTile *));
	*p = tile;
	luaL_getmetatable(L, "JiveTile");
	lua_setmetatable(L, -2);
	return 1;
}

int jiveL_tile_load_htiles(lua_State *L) {
	JiveTile *tile;
	JiveTile **p;

	/*
	  class
	  path table [3 entries]
	*/
	const char *paths[3];
	lua_rawgeti(L, 2, 1);
	paths[0] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 2);
	paths[1] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	lua_rawgeti(L, 2, 3);
	paths[2] = lua_isnil(L, -1) ? NULL : luaL_checkstring(L, -1);
	tile = jive_tile_load_htiles((char **)paths);
	lua_pop(L, 3);
	p = (JiveTile **)lua_newuserdata(L, sizeof(JiveTile *));
	*p = tile;
	luaL_getmetatable(L, "JiveTile");
	lua_setmetatable(L, -2);
	return 1;
}

int jiveL_tile_free(lua_State *L) {
	JiveTile *tile = *(JiveTile **)lua_touserdata(L, 1);
	if (tile) {
		jive_tile_free(tile);
	}
	return 0;
}

int jiveL_tile_blit(lua_State *L) {
	/*
	  tile
	  surface
	  x
	  y
	  w
	  h
	*/
	JiveTile *tile = *(JiveTile **)lua_touserdata(L, 1);
	JiveSurface *srf = *(JiveSurface **)lua_touserdata(L, 2);
	int x = luaL_checkint(L, 3);
	int y = luaL_checkint(L, 4);
	int w = luaL_checkint(L, 5);
	int h = luaL_checkint(L, 6);
	if (tile && srf) {
		jive_tile_blit(tile, srf, x, y, w, h);
	}
	return 0;
}

int jiveL_tile_min_size(lua_State *L) {
	/*
	  tile
	*/
	JiveTile *srf = *(JiveTile **)lua_touserdata(L, 1);
	Uint16 w, h;
	if (srf) {
		jive_tile_get_min_size(srf, &w, &h);
		lua_pushinteger(L, w);
		lua_pushinteger(L, h);
		return 2;
	}
	return 0;
}

int jiveL_surfacetile_gc(lua_State *L) {
	JiveTile *tile = *(JiveTile **)lua_touserdata(L, 1);
	if (tile) {
		jive_tile_free(tile);
	}
	return 0;
}

// concurrent resizer
#define  RESIZE_PENDING  0
#define  RESIZE_COMPLETE 1
#define  RESIZE_ERROR -1

//static pthread_t thread_resizer;
//static pthread_mutex_t resizer_lock; 
static SDL_Thread* resizer_thread = NULL;
static SDL_mutex* resizer_lock = NULL;


typedef struct resize_request {
	struct resize_request* perma_next;
	struct resize_request* next;
	char * src_path;
	char * dest_path;
	int   width;
	int   height;
	int   status;
	int   seq;
	int   op;
	int   save_as_bmp;
	SDL_Surface* src_sdl;
	SDL_Surface* dst_sdl;
} resize_request, *resize_request_ptr;

static resize_request_ptr resize_pending;
static resize_request_ptr resize_perma;

void vu_resize(resize_request_ptr req) {
	if (req->src_sdl != NULL) {
		int src_w = req->src_sdl->w;
		int src_h = req->src_sdl->h;
		int dst_w = (req->width/2) * req->seq;
		int dst_h = (src_h * dst_w)/src_w;
fprintf(stderr, "1) %d %d -> %d %d\n", src_w, src_h, dst_w, dst_h); fflush(stderr);
		if (req->width > 1280) {
			dst_w = (1280/2) * req->seq;
fprintf(stderr, "2) %d %d -> %d %d\n", src_w, src_h, dst_w, dst_h); fflush(stderr);
		}
		dst_h = (src_h * dst_w)/ src_w;
		if (dst_h > req->height) {
			dst_h = req->height;
			dst_w = (((src_w * req->height)/src_h)/req->seq) * req->seq;
fprintf(stderr, "3) %d %d -> %d %d\n", src_w, src_h, dst_w, dst_h); fflush(stderr);
		}
fprintf(stderr, "F) %d %d -> %d %d\n", src_w, src_h, dst_w, dst_h); fflush(stderr);
		req->dst_sdl = surface_newRGBA((Uint16)dst_w, (Uint16)dst_h);
	}
	if (req->src_sdl != NULL && req->dst_sdl != NULL) {
		copyResampled(req->dst_sdl, req->src_sdl, 0, 0, 0, 0, req->dst_sdl->w, req->dst_sdl->h, req->src_sdl->w, req->src_sdl->h);
	}
}

void sp_resize(resize_request_ptr req) {
	if (req->src_sdl != NULL) {
		req->dst_sdl = surface_newRGBA((Uint16)req->width, (Uint16)req->height);
		if (req->dst_sdl != NULL) {
			fprintf(stderr, "WxH ox: %d oy: %d dw: %d dh: %d sw: %d sh: %d\n", 0, 0, req->dst_sdl->w, req->dst_sdl->h, req->src_sdl->w, req->src_sdl->h); fflush(stderr);
			copyResampled(req->dst_sdl, req->src_sdl, 0, 0, 0, 0, req->dst_sdl->w, req->dst_sdl->h, req->src_sdl->w, req->src_sdl->h);
		}
	}
}

// scale the src image so that either width or height matches the destination
// and the other exceeds the destination.
// Then crop around the center.
void sp_scale_centered_crop(resize_request_ptr req) {
	sp_resize(req);
	if (req->src_sdl != NULL) {
		// Choose the largest scaling factor horizontal or vertical
		float f = ((float)req->width)/req->src_sdl->w;
		if (f < ((float)req->height)/req->src_sdl->h) {
			f = ((float)req->height)/req->src_sdl->h;
		}
		// Create an intermediate surface to hold the source image scaled by the scaling factor
fprintf(stderr, "### sr %d,%d -->>-- %d,%d\n", req->src_sdl->w, req->src_sdl->h, (Uint16)(f * req->src_sdl->w), (Uint16)(f * req->src_sdl->h)); fflush(stderr);
		SDL_Surface* tmp_sdl = surface_newRGBA((Uint16)(f * req->src_sdl->w), (Uint16)(f * req->src_sdl->h));
		if (tmp_sdl != NULL) {
			// Resize the source image to the new surface.
			copyResampled(tmp_sdl, req->src_sdl, 0, 0, 0, 0, tmp_sdl->w, tmp_sdl->h, req->src_sdl->w, req->src_sdl->h);
			// Create the destination surface
			// req->dst_sdl = surface_newRGBA((Uint16)req->width, (Uint16)req->height);
			if (req->dst_sdl != NULL) {
				// Centered blit clip - crops the surface to the destination surface
				SDL_Rect sr, dr;
				sr.x = (tmp_sdl->w - req->dst_sdl->w)/2;
				sr.y = (tmp_sdl->h - req->dst_sdl->h)/2;
				sr.w = req->dst_sdl->w; sr.h = req->dst_sdl->h;
				dr.x = 0; dr.y = 0;
				dr.w = 0; dr.h = 0;
				if (SDL_BlitSurface(tmp_sdl, &sr, req->dst_sdl, &dr) < 0) {
fprintf(stderr, "SSCC ########################## blit failed\n"); fflush(stderr);
				}
			}
			// Release the intermediate surface
//			SDL_FreeSurface(tmp_sdl);
		}
	}
}

void do_resize(resize_request_ptr req) {
		if (req != NULL) {
fprintf(stderr, "%s %s %dx%d\n", req->src_path, req->dest_path, req->width, req->height); fflush(stderr);
			int status = RESIZE_ERROR;
			req->src_sdl = IMG_Load(req->src_path);
			if (req->src_sdl->format->Amask) {
					req->src_sdl = SDL_DisplayFormatAlpha(req->src_sdl);
			} else {
					req->src_sdl = SDL_DisplayFormat(req->src_sdl);
			}
			switch(req->op) {
				case 1:
					vu_resize(req);
					break;
				case 2:
					sp_resize(req);
					break;
				case 3:
					sp_scale_centered_crop(req);
					break;
			}
			if (req->dst_sdl != NULL) {
				int saved;
				if (req->save_as_bmp) {
					saved = SDL_SaveBMP(req->dst_sdl, req->dest_path);
				} else {
					saved = save_png(req->dst_sdl, req->dest_path);
				}
				if (saved == 0) {
fprintf(stderr, "### saved %s\n", req->dest_path); fflush(stderr);
					status = RESIZE_COMPLETE;
				}
				SDL_FreeSurface(req->dst_sdl);
				req->dst_sdl = NULL;
			}
			if (req->src_sdl != NULL) {
				SDL_FreeSurface(req->src_sdl);
				req->src_sdl = NULL;
			}
			req->status = status;
fprintf(stderr, "resize done resize %d\n", req->status);
		}
}

// resizer thread - runs as daemon - polling every second
int fn_thread_resizer(void *ptr)
{
	resize_request_ptr req;
	while(1) {
		if (resize_pending != NULL) {
			if (SDL_LockMutex(resizer_lock) < 0) {
				fprintf(stderr, "mutex lock failed\n"); fflush(stderr);
				continue;
			}

			req = resize_pending;
			if (req != NULL) {
				resize_pending = req->next;
//				req->next = NULL;
			}
			if (SDL_UnlockMutex(resizer_lock) < 0) {
				fprintf(stderr, "mutex unlock failed\n"); fflush(stderr);
				return -1;
			}

			do_resize(req);
		} else {
			sleep(1);
		}
	}
	return  0;
}

void start_concurrent_resizer(void) {
	resizer_lock = SDL_CreateMutex();
	if (resizer_lock != NULL) {
		resizer_thread = SDL_CreateThread(fn_thread_resizer, NULL);
		if (resizer_thread != NULL) {
			fprintf(stderr,"started resizer thread\n");
		} else {
			fprintf(stderr,"failed to initialise lock\n");
		}
	} else {
		fprintf(stderr,"failed to initialise lock\n");
	}
	fflush(stderr);
}

int submit_resize_request(const char* src_path, const char* dest_path, int width, int height, int seq, int op, int save_as_bmp) {
	resize_request_ptr req = resize_perma;
	while(req != NULL) {
		if (req->width == width && req->height == height && strcmp(req->src_path, src_path)==0 && strcmp(req->dest_path, dest_path)==0) {
			return req->status;
		}
		req = req->next;
	}
	// allocation a single chunk of memory for the request + source and destination paths 
	size_t src_size = ((strlen(src_path) + 1 + sizeof(uintptr_t))/sizeof(uintptr_t)) * sizeof(uintptr_t);
	size_t dst_size = ((strlen(dest_path) + 1 + sizeof(uintptr_t))/sizeof(uintptr_t)) * sizeof(uintptr_t);
	size_t req_len = sizeof(*req) + src_size + dst_size;
	fprintf(stderr, "### calloc %ld\n", req_len); fflush(stderr);
	req = calloc(1, req_len);
	if (req != NULL) {
		req->width = width;
		req->height = height;
		req->seq = seq;
		req->op = op;
		req->save_as_bmp = save_as_bmp;
		req->src_path = (char *)(req + 1);
		strcpy(req->src_path, src_path);
		req->dest_path = req->src_path + src_size;
		strcpy(req->dest_path, dest_path);

		if (SDL_LockMutex(resizer_lock) < 0) {
			return RESIZE_ERROR;
		}

		req->next = resize_pending;
		resize_pending = req;
		req->perma_next = resize_perma;
		resize_perma = req;

		if (SDL_UnlockMutex(resizer_lock) < 0) {
			fprintf(stderr, "mutex unlock failed\n"); fflush(stderr);
			return RESIZE_ERROR;
		}

		return RESIZE_PENDING;
	}
	return RESIZE_ERROR;
}

// int is_resize_complete(const char* src_path, const char* dest_path, int width, int height) {
// 	resize_request_ptr req = resize_perma;
// 	while(req != NULL) {
// 		if (req->width == width && req->height == height && strcmp(req->src_path, src_path)==0 && strcmp(req->dest_path, dest_path)==0) {
// 			return req->status == 1;
// 		}
// 	}
// 	return RESIZE_ERROR;
// }

int jiveL_surface_request_resize(lua_State *L) {
	/*
	  class
	  src_imagepath
	  dest_imagepath
	  width
	  height
	  sequence count
	  operation  vu-meter 
	*/
	const char* src_path = luaL_checklstring(L, 2, NULL);
	const char* dest_path = luaL_checklstring(L, 3, NULL);
	int width = luaL_checkint(L, 4);
	int height= luaL_checkint(L, 5);
	int seq = luaL_checkint(L, 6);
	int op = luaL_checkint(L, 7);
	const char* image_type = luaL_checklstring(L, 8, NULL);

	int rsz = submit_resize_request(src_path, dest_path, width, height, seq, op, strcmp(image_type, "bmp"));

	lua_pushinteger(L, rsz);
	return 1;
}
