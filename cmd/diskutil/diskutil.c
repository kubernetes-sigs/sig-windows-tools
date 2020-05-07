/*
	diskutil.c
	A utility to enumerate disk devices and query id information 
*/

                                                  
#include <DriverSpecs.h>
_Analysis_mode_(_Analysis_code_type_user_code_)  

#include <windows.h>
#include <winioctl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <strsafe.h>
#include <setupapi.h> 
#include <devguid.h> 
#include <cfgmgr32.h>
#include "testapp.h"



DWORD Usage() {
	printf("Usage: diskutil <-option> <parameters>\n");
	printf("Usage: diskutil -GetDiskNumberWithId <Id>\n");
	return ERROR_INVALID_PARAMETER;
}


DWORD GetDiskNumber(HANDLE Disk, PLONG Number) {
	ULONG bytes;
	DWORD err = ERROR_SUCCESS;
	STORAGE_DEVICE_NUMBER devNum;
	*Number = -1;

	if (!DeviceIoControl(Disk, IOCTL_STORAGE_GET_DEVICE_NUMBER, NULL, 0, &devNum, sizeof(STORAGE_DEVICE_NUMBER), &bytes, FALSE)) {
		err = GetLastError();
		printf("IOCTL_STORAGE_GET_DEVICE_NUMBER failed: %d\n", err);
		return err;
	}
	*Number = devNum.DeviceNumber;
	return err;
}


DWORD DiskHasPage83Id(HANDLE Disk, PCHAR MatchId, ULONG MatchLen, PBOOL Found) {
	STORAGE_PROPERTY_QUERY qry;
	PSTORAGE_DEVICE_ID_DESCRIPTOR pDevIdDesc = NULL;
	PSTORAGE_IDENTIFIER pId = NULL;
	ULONG buffer_sz = 4*1024;
	ULONG sz = 0;
	ULONG m, n;
	DWORD err = ERROR_SUCCESS;

	*Found = FALSE;
	pDevIdDesc = (PSTORAGE_DEVICE_ID_DESCRIPTOR) malloc(buffer_sz);
	if (pDevIdDesc == NULL) {
		printf("Error allocating memory to get the query storage descriptors \n");
		err = ERROR_NOT_ENOUGH_MEMORY;
		goto EXIT;
	}

	qry.QueryType = PropertyStandardQuery;
	qry.PropertyId = StorageDeviceIdProperty;

	if (!DeviceIoControl(Disk, IOCTL_STORAGE_QUERY_PROPERTY, &qry, sizeof(STORAGE_PROPERTY_QUERY), pDevIdDesc, buffer_sz, &sz, NULL)) {
		err = GetLastError();
		printf("IOCTL_STORAGE_QUERY_PROPERTY failed: %d \n", err);
		goto EXIT;
	}

	pId = (PSTORAGE_IDENTIFIER) pDevIdDesc->Identifiers;

	for (n = 0; n < pDevIdDesc->NumberOfIdentifiers; n++) {
		if ((pId->CodeSet == StorageIdCodeSetAscii) && (pId->Association == StorageIdAssocDevice)) {
			if (MatchLen > pId->IdentifierSize) {
				continue;
			}
			for (m = 0; m < (pId->IdentifierSize - MatchLen + 1); m++) {
				if (memcmp(MatchId, pId->Identifier + m, MatchLen) == 0) {
					*Found = TRUE;
					goto EXIT;
				}
			}
		}
		pId = (PSTORAGE_IDENTIFIER)((ULONG_PTR)pId + pId->NextOffset);
	}

EXIT:
	if (pDevIdDesc != NULL) {
		free(pDevIdDesc);
	}
	return err;
}


DWORD GetDiskNumberWithId(PCHAR Id, ULONG IdLen, PLONG DiskNumber) {
	HANDLE hDevInfo = INVALID_HANDLE_VALUE;
	HANDLE hDisk = INVALID_HANDLE_VALUE;
	DWORD err = ERROR_SUCCESS;
	DWORD dwSize = 0;
	SP_DEVICE_INTERFACE_DATA spDevData;
	ULONG index = 0;
	BOOL status = FALSE;
	BOOL idFound = FALSE;
	PSP_DEVICE_INTERFACE_DETAIL_DATA spDevDetailData = NULL;

	spDevData.cbSize = sizeof(SP_INTERFACE_DEVICE_DATA);

	hDevInfo = SetupDiGetClassDevs((LPGUID) &DiskClassGuid, NULL, NULL, (DIGCF_PRESENT | DIGCF_INTERFACEDEVICE));
	if (hDevInfo == INVALID_HANDLE_VALUE) {
		err = GetLastError();
		printf("Error invoking SetupDiGetClassDevs: %d \n", err);
		goto EXIT;
	}

	while (SetupDiEnumDeviceInterfaces(hDevInfo, 0, &DiskClassGuid, index, &spDevData)) {
		status = SetupDiGetDeviceInterfaceDetail(hDevInfo, &spDevData, NULL, 0, &dwSize, NULL);
		if (!status) {
			err = GetLastError();
			if (err != ERROR_INSUFFICIENT_BUFFER) {
				printf("Error invoking SetupDiGetDeviceInterfaceDetail: %d\n", err);
				goto NEXT_DEVICE;
			}
		}

		spDevDetailData = (PSP_DEVICE_INTERFACE_DETAIL_DATA) malloc(dwSize);
		if (spDevDetailData == NULL) {
			printf("Error allocating memory to get the interface detail data \n");
			err = ERROR_NOT_ENOUGH_MEMORY;
			goto NEXT_DEVICE;
		}
		spDevDetailData->cbSize = sizeof(SP_INTERFACE_DEVICE_DETAIL_DATA);

		status = SetupDiGetDeviceInterfaceDetail(hDevInfo, &spDevData, spDevDetailData, dwSize, &dwSize, NULL);
		if (!status) {
			err = GetLastError();
			printf("Error invoking SetupDiGetDeviceInterfaceDetail: %d \n", err);
			goto NEXT_DEVICE;
		}

		// printf("disk device path: %s \n", spDevDetailData->DevicePath);
		hDisk = CreateFile(spDevDetailData->DevicePath, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
		if (hDisk == INVALID_HANDLE_VALUE) {
			err = GetLastError();
			printf("Error creating handle for disk: %s \n", spDevDetailData->DevicePath);
			goto NEXT_DEVICE;
		}

		err = DiskHasPage83Id(hDisk, Id, IdLen, &idFound);
		if (err != ERROR_SUCCESS) {
			goto NEXT_DEVICE;
		}

		if (idFound) {
			err = GetDiskNumber(hDisk, DiskNumber);
			goto EXIT;
		}

	NEXT_DEVICE:
		free(spDevDetailData);
		spDevDetailData = NULL;
		index++;
	}

	err = GetLastError();
	if (index == 0) {
		if (err != ERROR_NO_MORE_ITEMS) {
			printf("Error invoking SetupDiEnumDeviceInterfaces: %d \n", err);
			goto EXIT;
		}
		err = ERROR_NOT_FOUND;
		goto EXIT;
	}

EXIT:
	if (spDevDetailData != NULL) {
		free(spDevDetailData);
	}
	if (hDevInfo != INVALID_HANDLE_VALUE) {
		SetupDiDestroyDeviceInfoList(hDevInfo);
	}
	return err;
}


DWORD PrintDiskIDs(HANDLE Disk) {
	STORAGE_PROPERTY_QUERY qry;
	PSTORAGE_DEVICE_ID_DESCRIPTOR pDevIdDesc = NULL;
	PSTORAGE_DEVICE_DESCRIPTOR pDevDesc = NULL;
	PSTORAGE_IDENTIFIER pId = NULL;
	ULONG buffer_sz = 4 * 1024;
	ULONG sz = 0;
	ULONG n;
	DWORD err = ERROR_SUCCESS;

	pDevIdDesc = (PSTORAGE_DEVICE_ID_DESCRIPTOR)malloc(buffer_sz);
	if (pDevIdDesc == NULL) {
		printf("Error allocating memory to get the query storage descriptors \n");
		err = ERROR_NOT_ENOUGH_MEMORY;
		goto EXIT;
	}

	qry.QueryType = PropertyStandardQuery;
	qry.PropertyId = StorageDeviceIdProperty;

	if (!DeviceIoControl(Disk, IOCTL_STORAGE_QUERY_PROPERTY, &qry, sizeof(STORAGE_PROPERTY_QUERY), pDevIdDesc, buffer_sz, &sz, NULL)) {
		err = GetLastError();
		printf("IOCTL_STORAGE_QUERY_PROPERTY failed: %d \n", err);
		goto EXIT;
	}

	pId = (PSTORAGE_IDENTIFIER)pDevIdDesc->Identifiers;
	printf("    Disk IDs: %d\n", pDevIdDesc->NumberOfIdentifiers);

	for (n = 0; n < pDevIdDesc->NumberOfIdentifiers; n++) {
		printf("    Disk ID: Type %x CharSet %x Length %u ID: %s\n", pId->Type, pId->CodeSet, pId->IdentifierSize, pId->Identifier);
		pId = (PSTORAGE_IDENTIFIER)((ULONG_PTR)pId + pId->NextOffset);
	}

	pDevDesc = (PSTORAGE_DEVICE_DESCRIPTOR)malloc(buffer_sz);
	if (pDevDesc == NULL) {
		printf("Error allocating memory to get the query storage descriptors \n");
		err = ERROR_NOT_ENOUGH_MEMORY;
		goto EXIT;
	}

	qry.QueryType = PropertyStandardQuery;
	qry.PropertyId = StorageDeviceProperty;

	if (!DeviceIoControl(Disk, IOCTL_STORAGE_QUERY_PROPERTY, &qry, sizeof(STORAGE_PROPERTY_QUERY), pDevDesc, buffer_sz, &sz, NULL)) {
		err = GetLastError();
		printf("IOCTL_STORAGE_QUERY_PROPERTY failed: %d \n", err);
		goto EXIT;
	}
	PCHAR id = (PCHAR)pDevDesc + pDevDesc->SerialNumberOffset;
	printf("    Disk ID: %s\n", id);
	id = (PCHAR)pDevDesc + pDevDesc->VendorIdOffset;
	printf("    Disk Vendor ID: %s\n", id);
	id = (PCHAR)pDevDesc + pDevDesc->ProductIdOffset;
	printf("    Disk Product ID: %s\n", id);


	printf("\n");
EXIT:
	if (pDevIdDesc != NULL) {
		free(pDevIdDesc);
	}
	return err;
}


DWORD DumpDiskIDs() {
	HANDLE hDevInfo = INVALID_HANDLE_VALUE;
	HANDLE hDisk = INVALID_HANDLE_VALUE;
	DWORD err = ERROR_SUCCESS;
	DWORD dwSize = 0;
	SP_DEVICE_INTERFACE_DATA spDevData;
	ULONG index = 0;
	BOOL status = FALSE;
	LONG lDiskNum = 0;
	PSP_DEVICE_INTERFACE_DETAIL_DATA spDevDetailData = NULL;

	spDevData.cbSize = sizeof(SP_INTERFACE_DEVICE_DATA);

	hDevInfo = SetupDiGetClassDevs((LPGUID)& DiskClassGuid, NULL, NULL, (DIGCF_PRESENT | DIGCF_INTERFACEDEVICE));
	if (hDevInfo == INVALID_HANDLE_VALUE) {
		err = GetLastError();
		printf("Error invoking SetupDiGetClassDevs: %d \n", err);
		goto EXIT;
	}

	while (SetupDiEnumDeviceInterfaces(hDevInfo, 0, &DiskClassGuid, index, &spDevData)) {
		status = SetupDiGetDeviceInterfaceDetail(hDevInfo, &spDevData, NULL, 0, &dwSize, NULL);
		if (!status) {
			err = GetLastError();
			if (err != ERROR_INSUFFICIENT_BUFFER) {
				printf("Error invoking SetupDiGetDeviceInterfaceDetail: %d\n", err);
				goto NEXT_DEVICE;
			}
		}

		spDevDetailData = (PSP_DEVICE_INTERFACE_DETAIL_DATA)malloc(dwSize);
		if (spDevDetailData == NULL) {
			printf("Error allocating memory to get the interface detail data \n");
			err = ERROR_NOT_ENOUGH_MEMORY;
			goto NEXT_DEVICE;
		}
		spDevDetailData->cbSize = sizeof(SP_INTERFACE_DEVICE_DETAIL_DATA);

		status = SetupDiGetDeviceInterfaceDetail(hDevInfo, &spDevData, spDevDetailData, dwSize, &dwSize, NULL);
		if (!status) {
			err = GetLastError();
			printf("Error invoking SetupDiGetDeviceInterfaceDetail: %d \n", err);
			goto NEXT_DEVICE;
		}

		printf("Disk device path: %s \n", spDevDetailData->DevicePath);
		hDisk = CreateFile(spDevDetailData->DevicePath, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
		if (hDisk == INVALID_HANDLE_VALUE) {
			err = GetLastError();
			printf("Error creating handle for disk: %s \n", spDevDetailData->DevicePath);
			goto NEXT_DEVICE;
		}

		err = GetDiskNumber(hDisk, &lDiskNum);
		if (err != ERROR_SUCCESS) {
			goto NEXT_DEVICE;
		}
		printf("Disk number: %ld\n", lDiskNum);

		err = PrintDiskIDs(hDisk);
		if (err != ERROR_SUCCESS) {
			goto NEXT_DEVICE;
		}

	NEXT_DEVICE:
		free(spDevDetailData);
		spDevDetailData = NULL;
		index++;
	}

	err = GetLastError();
	if (index == 0) {
		if (err != ERROR_NO_MORE_ITEMS) {
			printf("Error invoking SetupDiEnumDeviceInterfaces: %d \n", err);
			goto EXIT;
		}
		err = ERROR_NOT_FOUND;
		goto EXIT;
	}

EXIT:
	if (spDevDetailData != NULL) {
		free(spDevDetailData);
	}
	if (hDevInfo != INVALID_HANDLE_VALUE) {
		SetupDiDestroyDeviceInfoList(hDevInfo);
	}
	return err;
}

INT __cdecl
main(
	_In_ ULONG argc,
	_In_reads_(argc) PCHAR argv[]
)
{
	LONG lDiskNum = 0;
	DWORD err = ERROR_SUCCESS;
	if (argc < 2 || argv[1][0] != '-')
	{
		return Usage();
	}

	if (strncmp(argv[1], "-DumpIDs", 8) == 0) {
		err = DumpDiskIDs();
		return err;
	}

	if (strncmp(argv[1], "-GetDiskNumberWithId", 20) == 0) {
		if (argc < 3) {
			return Usage();
		}
		err = GetDiskNumberWithId(argv[2], strnlen(argv[2], 1024), &lDiskNum);
		if (err == ERROR_SUCCESS) {
			if (lDiskNum >= 0) {
				printf("%d\n", lDiskNum);
			}
		}
		return err;
	}

	return Usage();

}
