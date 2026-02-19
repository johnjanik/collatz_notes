// Let x, C(x), C^2(x), ... , C^n(x)=x a non-trivial cycle in a Collatz sequence 
// and U the set of its odd members. Then we have 
// log_2(3) < n/|U| < log_2(3+my) with my = 1/|U| * (1/u_1 + ... + 1/u_|U|).
//
// If the value of my as the "mean reciprocal" of the odd members in the  
// Collatz sequence is bounded above, then with theory of continued fractions
// and best rational approximations we get a lower bound on the length n
// of this cycle.
//
// From now on such a cycle will be parted in segments (maybe of different length)
// and for every segment we show that the mean of the reciprocals of the
// odd numbers in this segment are smaller than a given value of my. Is
// this true for all segments, then it is for the entire cycle, also.
//
// The segments are always beginning with an odd number. Then we perform a 
// complete analysis of cases of this number modulo powers of 2. 
//
// Additionally we assume that for all sequences with starting number smaller than  
// or equal to X_0f we know that they are converging to the trivial cycle 1, 2. 
// So all numbers in our cycle are larger than X_0f.
//
// This program proves Corollary 19 of the paper.

#include "stdio.h"
#include <cmath>
#include <vector>
#include "time.h"
#include <iomanip>

double my = 1.3999; // The factor in my = constant * 1/X_0f is omitted.
double X_0f = 1.0;  // Actual value will be set in the main procedure.

const int depth = 200; // maximum number of steps in a segment
const int small_depth = 25; // depth for parallelizing step

uint64_t holdouts = 0; // number of residue classes modulo 2^depth with local_my>my 
double maxmy = 0.0;  // If holdouts > 0 this is the maximum local_my.
unsigned __int128 maxmy_res; // residue class mod 2^depth with maximum local_my
double maxfactor_f = 1.0; // maximum quotient of a sequence member / starting value
unsigned int max_nr_of_blocks_used = 1; // maximum number of blocks (monotonically
										// increasing subsequences) within a segment

// This helper function computes a factor how small a Collatz-predecessor
// of a given number can be, e.g., if a number n is == 2 (mod 3),
// there is a number n' with n' < 2/3 n and n is member of the Collatz
// sequence starting with n'. Since n is member of a nontrivial Collatz cycle
// the Collatz sequence starting with n' isn't converging to the 
// trivial cycle, too. Therefore, n'>X_0f, hence n> 3/2 * X_0f.
// Similarly values are calculated for different residue classes: 
// The variable odd is the number of previously done o-steps 
// and therefore the exponent of the power of 3 of the modulus. 
// We have laststepodd = 1, iff the last step was an o-step. In this case
// we do not have to consider the case 2 (mod 3), because this was done 
// while the test of the previous number in this sequence.
double corfactor(const unsigned int odd, const unsigned __int128 it_rest, const int laststepodd)
{
	const unsigned int rest = it_rest % 729;
	
	double minfactor = 1.0;
	double factor;

	if (odd >= 1)
	{		
		if (!laststepodd && (rest % 3 == 2)) //2k+1 --> 3k+2
		{
			factor = 2.0 / 3.0 * corfactor(odd - 1, it_rest / 3 * 2 + 1, 0);
			
			if (factor < minfactor)
				minfactor = factor;
		}
	}
	else
		return minfactor;

	if (odd >= 2)
	{		
		if (rest % 9 == 4) //8k+3 --> 9k+4 
		{
			factor = 8.0 / 9.0 * corfactor(odd - 2, it_rest / 9 * 8 + 3, 0);
			
			if (factor < minfactor)
				minfactor = factor;
		}
	}
	else
		return minfactor;

	if (odd >= 4) //64k+7 --> 81k+10
	{		
		if (rest % 81 == 10)
		{
			factor = 64.0 / 81.0 * corfactor(odd - 4, it_rest / 81 * 64 + 7, 0);
			
			if (factor < minfactor)
				minfactor = factor;
		}
	}
	else
		return minfactor;
	
	if (odd >= 5) //128k+95 --> 243k+182
	{		
		if (rest % 243 == 182)
		{
			factor = 128.0 / 243.0 * corfactor(odd - 5, it_rest / 243 * 128 + 95, 0);
			
			if (factor < minfactor)
				minfactor = factor;
		}
	}
	else
		return minfactor;

	if (odd >= 6)
	{	
		unsigned int p3 = 0;
		unsigned int rest2;
		
		switch (rest) // = "mod 729"
		{
			case  91: p3=6; rest2= 63; break; //512k+ 63 --> 729k+ 91
			case 410: p3=6; rest2=287; break; //512k+287 --> 729k+410
			case 433: p3=6; rest2=303; break; //512k+303 --> 729k+433
			case 524: p3=6; rest2=367; break; //512k+367 --> 729k+524
			case 587: p3=6; rest2=411; break; //512k+411 --> 729k+587
			case 604: p3=6; rest2=423; break; //512k+423 --> 729k+604
			case 661: p3=6; rest2=463; break; //512k+463 --> 729k+661
			case 695: p3=6; rest2=487; break; //512k+487 --> 729k+695
		}
		
		if (p3 == 6)
		{
			factor = 512.0 / 729.0 
			        * corfactor(odd-6,it_rest/729 * 512 + rest2, 0);
			
			if (factor < minfactor)
				minfactor = factor;
		}
	}
	else
		return minfactor;
	
	return minfactor;
}

// precalculating powers of 2 and 3
unsigned __int128 pow2[80];
unsigned __int128 pow3[80];
double pow2f[200];

void pow_init()
{
	pow2[0] = 1;
	pow3[0] = 1;
	pow2f[0] = 1;
	
	int i;
	for (i = 1; i < 80; i++)
	{
		pow2[i]  = 2 * pow2[i-1];
		pow3[i]  = 3 * pow3[i-1];
		pow2f[i] = 2 * pow2f[i-1];
	}
	
	for ( ; i < 200; i++)
	{
		pow2f[i] = 2 * pow2f[i-1];
	}
}

// printing int128 in decimal format
// every 6 digits a comma
void printf_128(unsigned __int128 number) 
{
	int digit[42];
	int cnt = 0;
	int loop;

	while (number>0)
	{	
		digit[cnt]=number%10;
		number=number/10;
		cnt++;
	}

	for (loop=cnt-1;loop>=0;loop--)
	{
		printf("%i",digit[loop]);
		if ( (loop%6==0) && (loop>0) )
		printf(",");
	}
}



// The working horse, the main program:

// The program works recursively: For every starting number x of a segment
// we first differentiate the cases of x mod 2^1. (Since x is odd by condition, 
// only in the case x == 1 (mod 2) something is to do.) By knowing
// the congruence class of x mod 2^1 the next 1 successor in the Collatz sequence
// can be computed. If the property we want to show is already proven, we can finish
// this case. Otherwise, we consider the two subcases of x mod 2^2. Then we 
// can compute the next 2 numbers in die Collatz sequence, and so on.
// We conclude a (sub)case, if we could prove the property or the maximum
// depth is reached. (In the later case the whole proof failed and there were
// holdouts. Thus, if there are no holdouts then in every case we have proven
// the property, and therefore it is valid for all nontrivial cycles.)

// This recursive search is done by the method iteration. Its first parameter, nr_it,
// is the number of the current iteration, i.e. the congruences are done
// modulo 2^nr_it. The second  parameter is the datapoint in. This data structure
// lists all calculations from previous steps for this starting number. 
// There rest_start is the residue class of the starting number x, i.e. 
// x = k * 2^nr_it + rest_start with a variable nonnegative integer k.  
// After nr_it Collatz steps from x we get k*3^odd + rest_it (also part of  
// the data structure). The next value in a datapoint is the minimum m_min of all 
// "mean reciprocals" of beginning subsequences of this segment.
// This is followed by is the "current value" m of the "mean reciprocal".
// (Both values are given in multiples of 1/x.) Next value is 
// a floating point approximation rest_start_f of x, followed by factor_f, 
// which is the ratio of the current iteration and x. Last value in the structure 
// in the structure datapoint is minfactor_f, the ratio of the smallest 
// member in this segment and the starting number x.

struct datapoint {
	unsigned __int128 rest_start;
	unsigned int odd;
	unsigned __int128 rest_it;
	double m_min;
	double m;
	double rest_start_f;
	double factor_f;
	double minfactor_f;
	unsigned int nr_of_blocks;
	unsigned int laststepodd;
	unsigned int nr_in_curr_block;
	double factor_curr_block;
	unsigned int last_block_for_min;
};

std::vector<struct datapoint> small_it_datapoint_array; // Dataset for parallelizing
														// after small_depth steps


// Calling this function at start with parameters for k*2^1 + 1 --> k*3^1 + 2:
// nr_it = 1, rest_start = 1, odd = 1, rest_it = 2, m_min = 3.0, m = 3.0, rest_start_f = 1.0, 
// factor_f = 1.5, minfactor_f = 1.0, nr_of_blocks = 1, laststeppodd = 1,
// nr_in_curr_block = 1, factor_curr_block = 1.0; last_block_for_min = 1

void iteration(const int nr_it, const struct datapoint in)
{
	// There are two cases for the next iteration:
	// x == in.rest_start (mod 2^(nr_it+1)) or x == in.rest_start + 2^nr_it (mod 2^(nr_it+1))
	
	// 1st case: x == rest_start (mod 2^(nr_it+1))
	{
		// k * 2^(nr_it+1) + in.rest_start ---(after nr_it steps)--> k*3^in.odd*2 + in.rest_it
		// Since the first summand k*3^in.odd*2 is even only the summand rest_it
		// determines the next Collatz step, if it is even or odd. 
		// In both subcases we can compute the next number in die Collatz
		// sequence k*3^new_odd + new_rest_it.
		
		struct datapoint out;
		
		out.rest_start = in.rest_start;
		out.rest_start_f = in.rest_start_f;
		out.nr_of_blocks = in.nr_of_blocks;
		out.m = in.m;
		out.nr_in_curr_block = in.nr_in_curr_block;
		out.factor_curr_block = in.factor_curr_block;
		out.last_block_for_min = in.last_block_for_min;
			
		if ((in.rest_it & 1) == 0)
		{
			out.odd = in.odd;
			out.rest_it = in.rest_it >> 1;
			out.factor_f = in.factor_f * 0.5;
			
			out.laststepodd = 0;
			
			if (in.laststepodd == 1)
			{
				//double geom_f = 1.0 - pow(2.0/3.0, in.nr_in_curr_block);
				//out.m = (in.m * in.nr_of_blocks - in.factor_curr_block 
				//         + geom_f * in.factor_curr_block) / in.nr_of_blocks;
				
				out.m = in.m - pow(2.0/3.0, in.nr_in_curr_block) 
				               * 3 * in.factor_curr_block / in.nr_of_blocks;
			}
		}
		else
		{
			out.odd = in.odd + 1;
			out.rest_it = in.rest_it + (in.rest_it >> 1) + 1;
			out.factor_f = in.factor_f * 1.5;
			if (out.factor_f > maxfactor_f) maxfactor_f = out.factor_f; 
			
			out.laststepodd = 1;
			if (in.laststepodd == 0)
			{
				out.nr_of_blocks++;
				out.nr_in_curr_block = 1;
				out.factor_curr_block = in.factor_f;
				out.m = (in.m * in.nr_of_blocks + 3.0 / in.factor_f) / out.nr_of_blocks;
			}
			else
			{
				out.nr_in_curr_block++;
			}
		}
		
		out.minfactor_f = out.factor_f * corfactor(out.odd, out.rest_it, out.laststepodd);
		if (in.minfactor_f < out.minfactor_f) out.minfactor_f = in.minfactor_f;

		out.m_min = in.m_min;
		if (out.m < out.m_min) 
		{
			out.m_min = out.m;
			out.last_block_for_min = out.nr_of_blocks;
			
			if (max_nr_of_blocks_used < out.last_block_for_min)
			{
				#pragma omp critical
				{
					max_nr_of_blocks_used = out.last_block_for_min;
				}
			}
		}
		
		double local_min_my = out.m_min * out.minfactor_f;
		
		if (out.laststepodd == 1)
		{
			//l_i>=2
			double min_f_lgeq2 = out.factor_curr_block / 2.0;
			if (out.minfactor_f < min_f_lgeq2)
				min_f_lgeq2 = out.minfactor_f;
			double cor_f = min_f_lgeq2 / out.minfactor_f;
			
			//l_i=1
			
			double nextm = (out.m * out.nr_of_blocks 
			                + 3.0 / (out.factor_f/2)) / (out.nr_of_blocks + 1);
			
			double maxval = nextm * out.minfactor_f;
			if (maxval > out.m_min)
				maxval = out.m_min;
			
			if (maxval < cor_f*out.m_min)
				maxval = cor_f*out.m_min;
			
			local_min_my = maxval;
		}
		
		if ((nr_it < depth-1) && (local_min_my >= my))
		{
			if (nr_it == small_depth - 1)
			{
				
				small_it_datapoint_array.push_back(out);
			}
			else
			{
				iteration(nr_it+1, out/*, S*/);
			}
		}
		else
		{
			if ((nr_it == depth - 1) && (local_min_my >= my))
			{
				#pragma omp critical
				{
					holdouts += out.odd;
					if (local_min_my > maxmy)
					{
						maxmy = local_min_my;
						maxmy_res = out.rest_start;
					}
				}
			}
		}
	}
	
	
		// The 2nd case x == in.rest_start + 2^nr_it (mod 2^(nr_it+1)) 
		// only needs to be considered if in.rest_start + 2^nr_it = x <= 1/my,
		// since otherwise 1/x < my proves the property directly. 
		
	double new_rest_start_f = in.rest_start_f + pow2f[nr_it];
	
	if (my/X_0f <= in.m_min*in.minfactor_f/new_rest_start_f)
	{
		// k * 2^(nr_it+1) + 2^nr_it + rest_start ---(after nr_it steps)--> (2k+1)*3^odd + rest_it
		// Since the first addend (2k+1)*3^odd is odd, only rest_it
		// determines the next Collatz iteration. In the subcases of
		// rest_it being odd or even one can compute the next number in
		// the Collatz sequence: k*3^new_odd + new_rest_it.
		
		struct datapoint out;
		
		out.rest_start = in.rest_start + pow2[nr_it];
		out.rest_start_f = new_rest_start_f;
		out.rest_it = in.rest_it + pow3[in.odd];
		out.m = in.m;
		out.nr_in_curr_block = in.nr_in_curr_block;
		out.nr_of_blocks = in.nr_of_blocks;
		out.factor_curr_block = in.factor_curr_block;
		out.last_block_for_min = in.last_block_for_min;
		
		if ((in.rest_it & 1) == 1) // i.e. rest_it + 3^odd is even
		{
			out.odd = in.odd;
			out.rest_it = out.rest_it >> 1;
			out.factor_f = in.factor_f * 0.5;
			
			out.laststepodd = 0;
			if (in.laststepodd == 1)
			{
				//double geom_f = 1.0 - pow(2.0/3.0, in.nr_in_curr_block);
				//out.m = (in.m * in.nr_of_blocks - in.factor_curr_block 
				//         + geom_f * in.factor_curr_block) / in.nr_of_blocks;
				
				out.m = in.m - pow(2.0/3.0, in.nr_in_curr_block) 
				               * 3 * in.factor_curr_block / in.nr_of_blocks;
			}
		}
		else
		{
			out.odd = in.odd + 1;
			out.rest_it = out.rest_it + (out.rest_it >> 1) + 1;
			out.factor_f = in.factor_f * 1.5;
			if (out.factor_f > maxfactor_f) maxfactor_f = out.factor_f;
			
			out.laststepodd = 1;
			if (in.laststepodd == 0)
			{
				out.nr_of_blocks++;
				out.nr_in_curr_block = 1;
				out.factor_curr_block = in.factor_f;
				out.m = (in.m * in.nr_of_blocks + 3.0 / in.factor_f) / out.nr_of_blocks;
			}
			else
			{
				out.nr_in_curr_block++;
			}
		}
		
		out.minfactor_f = out.factor_f * corfactor(out.odd, out.rest_it, out.laststepodd);
		if (in.minfactor_f < out.minfactor_f) out.minfactor_f = in.minfactor_f;

		out.m_min = in.m_min;
		if (out.m < out.m_min) 
		{
			out.m_min = out.m;
			out.last_block_for_min = out.nr_of_blocks;
			
			if (max_nr_of_blocks_used < out.last_block_for_min)
			{
				#pragma omp critical
				{
					max_nr_of_blocks_used = out.last_block_for_min;
				}
			}
		}

		double local_min_my = out.m_min * out.minfactor_f;
		
		if (out.laststepodd == 1)
		{
			//l_i>=2
			double min_f_lgeq2 = out.factor_curr_block / 2.0;
			if (out.minfactor_f < min_f_lgeq2)
				min_f_lgeq2 = out.minfactor_f;
			double cor_f = min_f_lgeq2 / out.minfactor_f;
			
			//l_i=1
			
			double nextm = (out.m * out.nr_of_blocks 
			                + 3.0 / (out.factor_f/2)) / (out.nr_of_blocks + 1);
			
			double maxval = nextm * out.minfactor_f;
			if (maxval > out.m_min)
				maxval = out.m_min;
			
			if (maxval < cor_f*out.m_min)
				maxval = cor_f*out.m_min;
			
			local_min_my = maxval;
		}
		
		if ((nr_it < depth-1) && (local_min_my >= my))
		{
			if (nr_it == small_depth - 1)
			{
				
				small_it_datapoint_array.push_back(out);
			}
			else
			{
				iteration(nr_it+1, out/*, S*/);
			}
		}
		else
		{
			if ((nr_it == depth - 1) && (local_min_my >= my))
			{
				#pragma omp critical
				{
					holdouts += out.odd;
					if (local_min_my > maxmy)
					{
						maxmy = local_min_my;
						maxmy_res = out.rest_start;
					}
				}
			}
		}
	}
}


int main()
{
	pow_init();
	
	X_0f = 695*pow2f[60]; 
	
	FILE *f_results;
	time_t curtime;
	
	// k*2^1+1 --> k*3^1 + 2
	
	struct datapoint start;
	
	start.rest_start = 1;
	start.odd = 1;
	start.rest_it = 2;
	start.m_min = 3.0; 
	start.m = 3.0; 
	start.rest_start_f = 1.0; 
	start.factor_f = 1.5; 
	start.minfactor_f = 1.0;
	start.nr_of_blocks = 1;
	start.laststepodd = 1;
	start.nr_in_curr_block = 1; 
	start.factor_curr_block = 1.0;
	start.last_block_for_min = 1;
	
	for ( ; (my > 0.1) && (holdouts < 100); my-=0.01)
	{
		printf("Test of mu=%f:\n", my);
		holdouts = 0;
		max_nr_of_blocks_used = 1;
		
		iteration(1, start);
		int counter = small_it_datapoint_array.size();
		
		printf("Number of residue classes modulo 2^%d needed to be considered: %d\n",
		       small_depth, counter);
		
		if (holdouts < 0)
		{
			f_results = fopen("results.txt","a");
			fprintf(f_results, "Error: small_it_datapoint_array is to small!\n");
			fclose(f_results);
			
			return 1;
		}
		
		int i;
		
		#pragma omp parallel for private(i) shared(holdouts, maxmy, maxmy_res, counter) schedule(dynamic)
		for (i=0; i < counter; i++)
		{
			iteration(small_depth, small_it_datapoint_array[i]);
		}
		
		f_results = fopen("results.txt","a");
		time(&curtime);
		
		fprintf(f_results,"%smu=%f", ctime(&curtime), my);
		fflush(f_results);
		
		if (holdouts != 0)
		{
			printf("\n\nNumber of odd members in failed residue classes: %ld\n\n",holdouts);
			printf("Maximum mu: %f * 'value wanted' in restidue class ", maxmy / my);
			printf_128(maxmy_res);
			printf(" mod 2^%d\n",depth);
			
			fprintf(f_results," Holdouts: %ld, maxmy= %f", holdouts, maxmy / my);
			
			break;
		}
		else
		{
			printf("\n\nProof succeeded!\n");
			printf("Maximum number of increasing subsequences in a segment: %d\n\n\n",
			       max_nr_of_blocks_used);
			
			fprintf(f_results, " Proof succeeded!");
			fprintf(f_results, "Maximum number of increasing subsequences in a segment: %d\n", 
			        max_nr_of_blocks_used);
		}
		
		fprintf(f_results, " Maximum factor_f: %f\n\n",maxfactor_f);
		fflush(f_results);
		fclose(f_results);
		
		small_it_datapoint_array.clear();
	}
	
	small_it_datapoint_array.clear();
	
	printf("Press Enter to end the program.\n");		
	getchar();
		
	return 0;
}
