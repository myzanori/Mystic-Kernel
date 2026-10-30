/*
 *
 * yixue.ge
 *
 */
#ifndef _OPLUS_BRIGHTSCREEN_CHECK_H_
#define _OPLUS_BRIGHTSCREEN_CHECK_H_

#ifdef CONFIG_OPLUS_FEATURE_THEIA
int bright_screen_timer_restart(void);
#else
static inline int bright_screen_timer_restart(void) { return 0; }
#endif

#endif

