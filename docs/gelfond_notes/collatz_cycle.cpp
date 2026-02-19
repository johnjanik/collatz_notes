/// Let x, C(x), C^2(x), ... , C^n(x)=x a non-trivial cycle in a Collatz sequence 
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
// or equal to S we know that they are converging to the trivial cycle 1, 2. 
// So all numbers in our cycle are larger than S.
//
// This program proves Corollary 29 of the paper.
//
// Values for S to be checked have to be given in the file worktodo.txt.

#include "stdio.h"
#include <cmath>
#include <vector>
#include "time.h"
#include <string>
#include <sstream>
#include <iomanip>
#include <iostream>
#include <fstream> 

const double my = 1.0/(4.37e+21); // The value needed to prove that every nontrivial
								  // Collatz cycle has to have at least 10^11 odd members
const int checkpoints_for_c_under = 2300;
const int depth = 300; // maximum number of steps in a segment
const int small_depth = 25; // depth for parallelizing step
std::ofstream ofs;

std::string timestampstring(const time_t &timestamp) // converting time_t in a readable format
{
	std::stringstream sst;
	sst << std::setfill('0');
	tm* now = localtime(&timestamp);
	sst << std::setw(2) << now->tm_mday << '.' << std::setw(2) << now->tm_mon+1 << '.'
		<< now->tm_year+1900 << " - " << std::setw(2) << now->tm_hour
		<< ':' << std::setw(2) << now->tm_min << ":" << std::setw(2) << now->tm_sec;
	return sst.str();
}

void printtime() // printing the current time in file and on screen
{
	time_t timestamp = time(0);
	
	std::cout << timestampstring(timestamp) << ": \n";
	ofs       << timestampstring(timestamp) << ": \n";
}

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
double pow2f[300];

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
	
	for ( ; i < 300; i++)
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
//
// The last parameter of the function is the bound S, where we assume that
// for all starting numbers x<S we already know that the respective Collatz
// sequences converge to the trivial cycle.

struct datapoint {
	unsigned __int128 rest_start;
	unsigned int odd;
	unsigned __int128 rest_it;
	double m_min;
	double m;
	double rest_start_f;
	double factor_f;
	double minfactor_f;
};

std::vector<struct datapoint> small_it_datapoint_array; // Dataset for parallelizing
														// after small_depth steps

// Calling this function at start with parameters for k*2^1 + 1 --> k*3^1 + 2:
// nr_it = 1, rest_start = 1, odd = 1, rest_it = 2, m_min = 3.0, m = 3.0, rest_start_f = 1.0, 
// factor_f = 1.5, minfactor_f = 1.0, nr_of_blocks = 1, laststeppodd = 1,
// nr_in_curr_block = 1, factor_curr_block = 1.0; last_block_for_min = 1
// (and value of S to be tested).

unsigned int iteration(const int nr_it, const struct datapoint in, const double S)
{
	unsigned int holdouts = 0;
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
	
		int laststepodd;
		
		if ((in.rest_it & 1) == 0)
		{
			out.odd = in.odd;
			out.rest_it = in.rest_it >> 1;
			out.factor_f = in.factor_f * 0.5;
			out.m = in.m;
			
			laststepodd = 0;
		}
		else
		{
			out.odd = in.odd + 1;
			out.rest_it = in.rest_it + (in.rest_it >> 1) + 1;
			out.factor_f = in.factor_f * 1.5;
			out.m = (in.m * in.odd + 1.0 / in.factor_f) / out.odd; 
			
			laststepodd = 1;
		}
		
		out.minfactor_f = out.factor_f * corfactor(out.odd, out.rest_it, laststepodd);
		if (in.minfactor_f < out.minfactor_f) out.minfactor_f = in.minfactor_f;

		out.m_min = in.m_min;
		if (out.m < out.m_min) out.m_min = out.m;
		
		double cor_x_f = out.rest_start_f; // If the smalles number in the segment
										   // (<= x*out.minfactor_f) is smaller than S
										   // then x can be raised until this isn't
										   // the case anymore, since as a member
										   // of a nontrivial cycle it has to be > S.
		if (out.rest_start_f * out.minfactor_f < S)
		{
			//x=k*2^(nr_it+1) + out.rest_start; "Min" <(k*2^(nr_it+1)+out.rest_start)*new_minfactor_f
			// We have S <= "Min", i.e. k >= (S/ out.minfactor_f - out.rest_start)/ 2^(nr_it+1)
			
			double k = std::ceil((S / out.minfactor_f - out.rest_start_f)/ pow2f[nr_it+1]);
			cor_x_f = out.rest_start_f + k * pow2f[nr_it+1];
		}
		
		double local_min_my = out.m_min / cor_x_f; // absolute value of smallest
												   // "mean reciprocal" of 
												   // beginning subsequences in
												   // the segment starting with x
		if ((nr_it < depth-1) && (local_min_my >= my))
		{
			if (nr_it == small_depth - 1)
			{
				
				small_it_datapoint_array.push_back(out);
			}
			else
			{
				holdouts += iteration(nr_it+1, out, S);
			}
		}
		else
		{
			if ((nr_it == depth - 1) && (local_min_my >= my))
			{

				holdouts ++;
			}
		}
	}
	
	
		// The 2nd case x == in.rest_start + 2^nr_it (mod 2^(nr_it+1)) 
		// only needs to be considered if in.rest_start + 2^nr_it = x <= 1/my,
		// since otherwise 1/x < my proves the property directly. 
		
	double new_rest_start_f = in.rest_start_f + pow2f[nr_it];
	
	if (new_rest_start_f <= 1/my)
	{
		// k * 2^(nr_it+1) + 2^nr_it + rest_start ---(after nr_it steps)--> (2k+1)*3^odd + rest_it
		// Since the first addend (2k+1)*3^odd is odd, only rest_it
		// determines the next Collatz iteration. In the subcases of
		// rest_it being odd or even one can compute the next number in
		// the Collatz sequence: k*3^new_odd + new_rest_it
		
		struct datapoint out;
		
		out.rest_start = in.rest_start + pow2[nr_it];
		out.rest_start_f = new_rest_start_f;
		out.rest_it = in.rest_it + pow3[in.odd];

		int laststepodd;
		
		if ((in.rest_it & 1) == 1) // i.e. rest_it + 3^odd is even
		{
			out.odd = in.odd;
			out.rest_it = out.rest_it >> 1;
			out.factor_f = in.factor_f * 0.5;
			out.m = in.m;
			
			laststepodd = 0;
		}
		else
		{
			out.odd = in.odd + 1;
			out.rest_it = out.rest_it + (out.rest_it >> 1) + 1;
			out.factor_f = in.factor_f * 1.5;
			out.m = (in.m * in.odd + 1.0 / in.factor_f) / out.odd; 
			
			laststepodd = 1;
		}
		
		out.minfactor_f = out.factor_f * corfactor(out.odd, out.rest_it, laststepodd);
		if (in.minfactor_f < out.minfactor_f) out.minfactor_f = in.minfactor_f;

		out.m_min = in.m_min;
		if (out.m < out.m_min) out.m_min = out.m;
		
		double cor_x_f = out.rest_start_f; // If the smalles number in the segment
										   // (<= x*out.minfactor_f) is smaller than S
										   // then x can be raised until this isn't
										   // the case anymore, since as a member
										   // of a nontrivial cycle it has to be > S.
		if (out.rest_start_f * out.minfactor_f < S)
		{
			//x=k*2^(nr_it+1) + out.rest_start; "Min" <(k*2^(nr_it+1)+out.rest_start)*out.minfactor_f
			// We have S <= "Min", i.e. k >= (S/ out.minfactor_f - out.rest_start)/ 2^(nr_it+1)
					
			double k = std::ceil((S / out.minfactor_f - out.rest_start_f)/ pow2f[nr_it+1]);
			cor_x_f = out.rest_start_f + k * pow2f[nr_it+1];
		}
		
		double local_min_my = out.m_min / cor_x_f; // absolute value of smallest
												   // "mean reciprocal" of 
												   // beginning subsequences in
												   // the segment starting with x
		if ((nr_it < depth-1) && (local_min_my >= my))
		{
			if (nr_it == small_depth - 1)
			{
				
				small_it_datapoint_array.push_back(out);
			}
			else
			{
				holdouts += iteration(nr_it+1, out, S);
			}
		}
		else
		{
			if ((nr_it == depth - 1) && (local_min_my >= my))
			{
				holdouts++;
			}
		}
	}
	
	return holdouts;
}


// The work -- the values of S to check -- are given in the file
// worktodo.txt which has to be located in the working folder of the
// program. This method checks, if there is work to do.
bool isworktodo()
{
	std::ifstream f_worktodo;
    f_worktodo.open("worktodo.txt");
    std::string line;
    if (!getline(f_worktodo,line))
    {
		f_worktodo.close();
		return false;
	}
	else
	{
		f_worktodo.close();
		return true;
	}
}

// If there is work to do, extract the next value for S to be checked.
int get_next_number()
{
	std::ifstream f_worktodo;
    f_worktodo.open("worktodo.txt");
    int number;
    
    if (!f_worktodo.is_open()) {
        std::cout  << "Could not open the file ";
        return EXIT_FAILURE;
    }
  
    if (!(f_worktodo >> number))
    {
		std::cout << "Lesen fehlgeschlagen! ";
		f_worktodo.close();
		
		return 0;
	}
    
    f_worktodo.close();
   
    return number;
}

// After one value of S is checked, remove it (i.e. the first line) 
// from the worktodo.txt file.
void delete_first_line()
{
	std::ifstream f_worktodo;
    f_worktodo.open("worktodo.txt");
        
    std::string line;
    
    if (!getline(f_worktodo,line))
    {
		f_worktodo.close();
		return;
	}
    
    std::ofstream f_temp;
    f_temp.open("temp.txt");
    
    while (getline(f_worktodo,line))
    {
        f_temp << line << std::endl;
    }
    f_temp.close();
    f_worktodo.close();
    remove("worktodo.txt");
    rename("temp.txt","worktodo.txt");
    
    return;
}

int main()
{
	pow_init();
	
	double S; 
	
	// k*2^1+1 --> k*3^1 + 2
	
	struct datapoint start;
	
	start.rest_start = 1;
	start.odd = 1;
	start.rest_it = 2;
	start.m_min = 1.0;
	start.m = 1.0;
	start.rest_start_f = 1.0; 
	start.factor_f = 1.5; 
	start.minfactor_f = 1.0;
		
	ofs.open ("output.txt", std::ofstream::out | std::ofstream::app);
	ofs << "The following calculations are made for my=" << my << ":" << std::endl << std::endl;
	ofs.close();
	
	
	while (isworktodo())
	{
		int c = get_next_number();
		
		if (c==0)
		{
			delete_first_line();
			break;
		}
			
		S = c * pow2f[60];
		ofs.open ("output.txt", std::ofstream::out | std::ofstream::app);
		std::cout << "\n" << "Test of S = " << c << " * 2^60:\n";
		ofs << "\n" << "Test of S = " << c << " * 2^60:\n";
		unsigned int holdouts = 0;
		
		iteration(1, start, S);
		int counter = small_it_datapoint_array.size();
		
		std::cout << "Number of residue classes modulo 2^" << small_depth
				  << "needed to be considered: " << counter << std::endl;
		ofs       << "Number of residue classes modulo 2^" << small_depth
				  << "needed to be considered: " << counter << std::endl;
		ofs.close();
		
		std::vector<bool> done (counter, false);
		
		std::stringstream sstr;
		sstr << "checkpointfile_" << c << ".txt";
		std::string checkpoint_filename = sstr.str();
		sstr.str("");
		int no_of_done = 0;
		unsigned int local_holdouts;
		
		if (c<checkpoints_for_c_under)
		{
			std::ifstream cpf;
			cpf.open(checkpoint_filename);
			int number;
			
			if (cpf.is_open())
			{
				while (cpf >> number >> local_holdouts)
				{
					if ((0<= number) && (number < counter))
					{
						if (local_holdouts == 0)
							done[number] = true;
							
						holdouts += local_holdouts;
					}
				}
				
				cpf.close();
			} 
		}
		
				
		int i;
		
		#pragma omp parallel for private(i) shared(holdouts, counter) schedule(dynamic) //num_threads(2)
		for (i=0; i < counter; i++)
		{
			if (!done[i])
			{
				local_holdouts = iteration(small_depth, small_it_datapoint_array[i], S);
			
				done[i] = true;
				if (c<checkpoints_for_c_under)
				{
					#pragma omp critical
					{
						std::ofstream cp_f;
						cp_f.open (checkpoint_filename, std::ofstream::out | std::ofstream::app);
						cp_f << i << " " << local_holdouts << std::endl;
						cp_f.close();
						
						holdouts += local_holdouts;
					}
				}
			}
			
			#pragma omp critical
			{
				no_of_done++;
				if ((c<checkpoints_for_c_under) && (no_of_done% 100 == 0))
				{
					std::cout << "number of checked residue classes: "
							  << no_of_done << " of " << counter
							  << "." << std::endl;
				}
			}
		}
		
		ofs.open("output.txt", std::ofstream::out | std::ofstream::app);
		
		printtime();
		
		if (holdouts != 0)
		{
			std::cout << "\n\nNumber of failed residue classes mod 2^"
			          << depth << ": " << holdouts << std::endl << std::endl;
			
			ofs << " Holdouts: " << holdouts << std::endl;
		}
		else
		{
			std::cout << "\n\nProof succeeded!\n";
			
			ofs << " Proof succeeded!!";
		}
		
		ofs.close();
		
		small_it_datapoint_array.clear();
		done.clear();
		
		delete_first_line();		
	}
	
	printf("Press Enter to end the program.\n");		
	getchar();
		
	return 0;
}
