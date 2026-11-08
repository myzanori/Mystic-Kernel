// SPDX-License-Identifier: GPL-2.0
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/string.h>

#ifdef CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
extern struct static_key_false susfs_is_fake_cmdline_or_bootconfig_buffer_set;
extern void susfs_spoof_cmdline_or_bootconfig(struct seq_file *m);
#endif

static int cmdline_proc_show(struct seq_file *m, void *v)
{
#ifdef CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
	if (static_branch_likely(&susfs_is_fake_cmdline_or_bootconfig_buffer_set)) {
		susfs_spoof_cmdline_or_bootconfig(m);
		seq_putc(m, '\n');
		return 0;
	}
#endif
	if (saved_command_line) {
		char *buf = kstrdup(saved_command_line, GFP_KERNEL);
		if (buf) {
			char *p;
			while ((p = strstr(buf, "androidboot.verifiedbootstate=orange"))) {
				memcpy(p, "androidboot.verifiedbootstate=green", 35);
				memmove(p + 35, p + 36, strlen(p + 36) + 1);
			}
			while ((p = strstr(buf, "androidboot.flash.locked=0"))) {
				*(p + 25) = '1';
			}
			seq_puts(m, buf);
			kfree(buf);
			seq_putc(m, '\n');
			return 0;
		}
	}
	seq_puts(m, saved_command_line);
	seq_putc(m, '\n');
	return 0;
}

static int __init proc_cmdline_init(void)
{
	proc_create_single("cmdline", 0, NULL, cmdline_proc_show);
	return 0;
}
fs_initcall(proc_cmdline_init);
