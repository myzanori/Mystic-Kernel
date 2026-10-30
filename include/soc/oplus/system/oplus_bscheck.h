/*
 *
 * yixue.ge
 *
 */
#ifndef _OPLUS_BS_CHECK_H_
#define _OPLUS_BS_CHECK_H_

#ifdef CONFIG_OPLUS_FEATURE_THEIA
int black_screen_timer_restart(void);
#else
static inline int black_screen_timer_restart(void) { return 0; }
#endif

#endif

