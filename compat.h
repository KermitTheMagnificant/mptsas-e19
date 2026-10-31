// Stops file from being processed twice
#ifndef MPT_COMPAT_H
#define MPT_COMPAT_H

// It works, thats all that matters (thank u claude)
#ifdef HAVE_SCSI_TIMEOUT_ACTION
#define MPT_EH_TIMER_RET   enum scsi_timeout_action
#define MPT_EH_DONE        SCSI_EH_DONE
#define MPT_EH_RESET_TIMER SCSI_EH_RESET_TIMER
#else
#define MPT_EH_TIMER_RET   enum blk_eh_timer_return
#define MPT_EH_DONE        BLK_EH_DONE
#define MPT_EH_RESET_TIMER BLK_EH_RESET_TIMER
#endif

#ifdef HAVE_BLK_QUEUE_DMA_ALIGNMENT
#define MPT_SET_DMA_ALIGNMENT(q) blk_queue_dma_alignment((q), 512 - 1)
#else
#define MPT_SET_DMA_ALIGNMENT(q) do { } while (0)
#endif

#endif