// SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (C) 2019 Fredrik Noring
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "psgplay/sndh.h"

#include "text/main.h"
#include "text/mode.h"

static void main_title(struct vt_buffer *vtb, int row, const char *title)
{
	for (int c = 0, i = 0; c < vtb->server.size.cols; c++)
		vt_putc_reverse(vtb, row, c, title[i] ? title[i++] : ' ');
}

static void main_track(struct vt_buffer *vtb, int track, bool playing)
{
	if (track)
		vt_printf(vtb, 3 + track, 1,
			playing ? vt_attr_reverse : vt_attr_normal,
			"%2d.", track);
}

static void main_form(struct vt_buffer *vtb, const struct text_sndh *sndh)
{
	for (int i = 0; i < sndh->subtune_count; i++)
		main_track(vtb, i + 1, false);
}

static void main_data(struct vt_buffer *vtb, const struct text_sndh *sndh)
{
	int subtune = 0;

	sndh_for_each_tag (sndh->data, sndh->size)
		if (strcmp(sndh_tag_name, "COMM") == 0) {
			vt_printf(vtb, 1, 0, vt_attr_normal,
				"%s", sndh_tag_value);
		} else if (strcmp(sndh_tag_name, "!#SN") == 0) {
			subtune++;

			vt_printf(vtb, 3 + subtune, 5,
				vt_attr_normal, "%s", sndh_tag_value);
		}

	if (!subtune)
		for (int i = 0; i < sndh->subtune_count; i++)
			vt_printf(vtb, 4 + i, 5, vt_attr_normal,
				"%s", sndh->title);

	vt_printf(vtb, 2, 0, vt_attr_normal, "%s", sndh->title);
}

static void cursor_hide(struct vt_buffer *vtb, int cursor)
{
	if (cursor)
		vt_putc_normal(vtb, 3 + cursor, 0, ' ');
}

static void cursor_show(struct vt_buffer *vtb, int cursor)
{
	if (cursor)
		vt_putc_normal(vtb, 3 + cursor, 0, '>');
}

static void cursor_update(struct vt_buffer *vtb,
	struct text_state *view, const struct text_state *model)
{
	if (model->cursor == view->cursor)
		return;

	cursor_hide(vtb, view->cursor);
	view->cursor = model->cursor;
	cursor_show(vtb, view->cursor);
}

static void track_update(struct vt_buffer *vtb,
	struct text_state *view, const struct text_state *model)
{
	if (model->track == view->track)
		return;

	main_track(vtb, view->track, false);
	view->track = model->track;
	main_track(vtb, view->track, true);
}

static u64 time_update(struct vt_buffer *vtb, struct text_state *view,
	const struct text_state *model, u64 timestamp)
{
	if (view->timestamp <= timestamp) {
		const int col = vtb->server.size.cols - 5;
		const int s = timestamp / 1000;
		const int m = s / 60;

		if (m < 60)
			vt_printf(vtb, 0, col, vt_attr_reverse,
				"%02d:%02d", m, s % 60);
		else
			vt_printf(vtb, 0, col, vt_attr_reverse, "--:--");

		view->timestamp = (s + 1) * 1000;
	}

	return view->timestamp;
}

static u64 main_view(struct vt_buffer *vtb, struct text_state *view,
	const struct text_state *model, const struct text_sndh *sndh,
	u64 timestamp)
{
	if (!view->cursor) {
		vt_clear(vtb);

		main_title(vtb, 0, "PSG play");

		main_form(vtb, sndh);
		main_data(vtb, sndh);

		main_title(vtb, vtb->server.size.rows - 1, "");
	}

	cursor_update(vtb, view, model);

	track_update(vtb, view, model);

	return time_update(vtb, view, model, timestamp);
}

static void main_ctrl(const unicode_t key, struct text_state *ctrl,
	const struct text_state *model, const struct text_sndh *sndh)
{
	if (key == 'j' || key == U_ARROW_DOWN)
		ctrl->cursor++;

	if (key == 'k' || key == U_ARROW_UP)
		ctrl->cursor--;

	ctrl->quit = (key == 'q' || key == '\033');
}

const struct text_mode text_mode_main = {
	.view = main_view,
	.ctrl = main_ctrl,
};