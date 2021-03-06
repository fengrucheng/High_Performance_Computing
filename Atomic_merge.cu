﻿#include <stdio.h>
#include <stdlib.h>

#define base_int unsigned int

#define NUM_ELEM 16
unsigned int data[NUM_ELEM] = { 124, 20, 5, 86, 240, 183, 68, 18, 24, 120, 15, 6, 40, 283, 38, 128 }

__device__ void radix_sort(base_int *arr, base_int n, base_int *tmp_1, base_int tid, base_int tdim)
{
	for (base_int bit = 0; bit < 32; bit++)
	{
		base_int base_0 = 0;
		base_int base_1 = 0;
		base_int bit_mask = (1 << bit);
		for (base_int i = 0; i < n; i += tdim)
		{
			base_int x = arr[i + tid];
			if ((x&bit_mask)>0)
			{
				tmp_1[base_1 + tid] = x;
				base_1 += tdim;
			}
			else
			{
				arr[base_0 + tid] = x;
				base_0 += tdim;
			}
		}
		for (base_int i = 0; i < base_1; i += tdim)
		{
			arr[i + base_0 + tid] = tmp_1[i + tid];
		}
	}
}

__device__ void merge_array2(base_int *arr, base_int *brr, base_int tid, base_int tdim, base_int n)
{
	base_int n1=n/tdim;
	__shared__ base_int list_index[1024];
	list_index[tid]=0;
	__syncthreads();
	for (base_int i = 0; i < n; i++)
	{
		__shared__ base_int min_val;
		__shared__ base_int min_idx;
		base_int x;
		if (list_index[tid] < n1)
		{
			base_int idx = tid + (list_index[tid] * tdim);
			x = arr[idx];
		}
		else
		{
			x = 0xFFFFFFFF;
		}
		if(tid==0)
		{
			min_idx=0xFFFFFFFF;
			min_val=0xFFFFFFFF;
		}
		__syncthreads();
		atomicMin(&min_val,x);
		__syncthreads();
		if (tid == x)
		{
			atomicMin(&min_idx,tid);
		}
		__syncthreads(); 
		if(tid==min_idx)
		{
			list_index[tid]++;
			brr[i]=x;
		}
	}
}	

__global__ void merge_sort_gpu(base_int *arr, base_int tdim, base_int n)
{
	base_int tid = blockDim.x * blockIdx.x + threadIdx.x;
	__shared__ base_int tmp[NUM_ELEM];
	__shared__ base_int tmp1[NUM_ELEM];

	for (base_int i = 0; i < n; i += tdim)
	{
		tmp[i + tid] = arr[i + tid];
	}
	__syncthreads();
	radix_sort(tmp, n, tmp1, tid, tdim);
	merge_array2(tmp, arr, tid, tdim, n);
}

int main(){

	cudaEvent_t start, stop;
	cudaEventCreate(&start);
	cudaEventCreate(&stop);

	size_t size = NUM_ELEM*sizeof(int);
	base_int *d_a;

	cudaMalloc((void **)&d_a, size);
	cudaMemcpy(d_a, data, size, cudaMemcpyHostToDevice);

	//stride
	base_int tdim = 2;
	cudaEventRecord(start);
	merge_sort_gpu << <1, tdim >> >(d_a, tdim, NUM_ELEM);
	cudaEventRecord(stop);

	cudaMemcpy(data, d_a, size, cudaMemcpyDeviceToHost);
	cudaFree(d_a);

	float milliseconds = 0;
	cudaEventElapsedTime(&milliseconds, start, stop);
	printf("Elapsed time (ms): %f\n", milliseconds);

	for (int i = 0; i < NUM_ELEM; i++)
	{
		printf("%d ", data[i]);
	}
	printf("\n");
		
	
	return EXIT_SUCCESS;
}

