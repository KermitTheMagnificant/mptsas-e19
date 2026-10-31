obj-m += mptbase.o mptscsih.o mptsas.o

hdr_scsi := $(srctree)/include/scsi
hdr_blk  := $(srctree)/include/linux/blkdev.h

ifneq ($(shell grep -rl "enum scsi_timeout_action" $(hdr_scsi) 2>/dev/null),)
ccflags-y += -DHAVE_SCSI_TIMEOUT_ACTION
endif

ifneq ($(shell grep -l "blk_queue_dma_alignment" $(hdr_blk) 2>/dev/null),)
ccflags-y += -DHAVE_BLK_QUEUE_DMA_ALIGNMENT
endif

ccflags-y += -include $(src)/compat.h