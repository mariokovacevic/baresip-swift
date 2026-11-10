#include "bsk_bridge.h"

uint32_t bsk_bridge_abi_version(void);

uint32_t bsk_bridge_abi_version(void)
{
	return bsk_abi_version();
}
