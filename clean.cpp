#include <iostream>
#include <string>
#include <ctime>
#include <vector>
#include <fstream>

using namespace std;

#define NUMBER "0123456789"
#define FILENAME "/home/adam/bin/clean_conf.txt"

void usage()
{
    cerr << "Usage: clean [item]" << endl;
    cerr << "Running with no argument displays what needs cleaning." << endl;
    cerr << "Running with an argument indicates that thing has been cleaned." << endl;
    cerr << "Running:" << endl;
    cerr << "clean all" << endl;
    cerr << "indicates that everything which needed cleaning has been cleaned." << endl;
    exit(1);
}

void parseLine(string line, string& task, int& freq, int& lastDayDone)
{
	string freqStr, lastDayDoneStr;
	size_t freqLoc = line.find_first_of(NUMBER);
    if (freqLoc == string::npos) {
        cerr << "Error at " << line << endl;
        exit(2);
    }
	size_t lastDayDoneLoc = line.find_first_of(" \t", freqLoc);
    if (lastDayDoneLoc == string::npos) {
        cerr << "Error at " << line << endl;
        exit(3);
    }
	lastDayDoneLoc = line.find_first_of(NUMBER, lastDayDoneLoc);
	freqStr = line.substr(freqLoc, lastDayDoneLoc - freqLoc);
	lastDayDoneStr = line.substr(lastDayDoneLoc);
    task = line.substr(0, freqLoc);
    freq = stoi(freqStr);
    lastDayDone = stoi(lastDayDoneStr);
}

int getDayOfYear()
{
    time_t timer;
    time(&timer);
    struct tm * timeinfo = localtime(&timer);
    return timeinfo->tm_yday;
}

bool needsCleaning(int dayOfYear, int freq, int lastDayDone)
{
	int effectiveDayOfYear;
    if (lastDayDone > dayOfYear) {
    	effectiveDayOfYear = dayOfYear + 365;
    } else {
    	effectiveDayOfYear = dayOfYear;
    }
    return lastDayDone + freq < effectiveDayOfYear;
}

int main(int argc, char** argv)
{
    if (argc > 2) {
        usage();
    }
    string arg = "";
    if (argc == 2) {
        arg = argv[1];
    }

    ifstream file(FILENAME);

    //Since we want to save the output back to the same file, keep the output in memory until the end
    vector<string> output;
    std::string line = "";
    int dayOfYear = getDayOfYear();
    while (std::getline(file, line)) {
        if (line.find_first_of(NUMBER) == string::npos) {
        	//Perhaps a comment or an otherwise invalid line in the input
            if (arg != "") {
                output.push_back(line);
            }
        } else {
			string task;
			int freq, lastDayDone;
			parseLine(line, task, freq, lastDayDone);
			if (arg == "") {
				if (needsCleaning(dayOfYear, freq, lastDayDone)) {
					cout << task << std::endl;
				}
			} else {
                if (arg == "all") {
                    if (needsCleaning(dayOfYear, freq, lastDayDone)) {
                        //Indicate that the task has been done and save it to the file
                        lastDayDone = dayOfYear;
                    }
                } else {
                    if (arg == task.substr(0, arg.length())) {
                        //Indicate that the task has been done and save it to the file
                        lastDayDone = dayOfYear;
                    }
                }
                string toOutput = task + to_string(freq) + " " + to_string(lastDayDone);
                output.push_back(toOutput);
			}
        }
    }
    file.close();
    if (arg != "") {
        ofstream outFile(FILENAME);
        for (string line : output) {
            outFile << line << endl;
        }
    }
}

