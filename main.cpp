#include <iostream>
#include <ctime>
#include <chrono>
#include <fstream>

using namespace std;

int **grayscale(double **rgbpic, int height, int width){
    /*
    Działająca funckja grayscale, do zrobienia na cudzie
    */
    int **picture;
    picture = new int* [height];
    for(int i = 0; i<height;++i) picture[i] = new int[width];

    for(int i=0;i<height;i++){
        for(int j=0;j<3*width;j+=3){

            picture[i][j/3] = 0.2627 * rgbpic[i][j] + 0.6780 * rgbpic[i][j+1] + 0.0593 * rgbpic[i][j+2];
        }
    }
    return picture;
}


int **myresize(int **picture4, int height, int width, int thumbheight, int thumbwidth){
    /*
    average of some pixels taken form the original image
    */
    
    int **picture3 = new int*[thumbheight];
    for(int i = 0; i<thumbheight;++i) picture3[i] = new int[thumbwidth];
    
    int xscale = 1 + height / thumbheight;
    int yscale = 1 + width / thumbwidth;
    int sum = 0;
    int amount = xscale * yscale;
    
    for(int i = 0; i < thumbheight; i++){
    
        for(int j = 0; j < thumbwidth; j++){

            for(int f = 0; f < xscale; ++f){
                for(int g = 0; g < yscale; ++g){
                    if(i*(xscale-1) + f < height && j*(yscale-1) + g < width){
                    sum += picture4[i*(xscale-1) + f][j*(yscale-1) + g];
                    }
                }
            }
            picture3[i][j] = sum / amount;
            sum = 0;
        }
    }

    return picture3;
}

int main(){
    
    
    fstream pic;
    fstream wymiary;
    fstream time_cpu;
    int height = 0;
    int width = 0;
    time_cpu.open("time_cpu.txt", fstream::in | fstream::app);
    wymiary.open("wymiary_ludzie.txt");
    wymiary >> height;
    wymiary >> width;
    wymiary.close();
    cout<< height << width <<'\n';
    //int num = 0;
    int counteri = 0;
    int counterj = 0;
    double **picture = new double*[height];
    for(int i=0;i<height;i++) picture[i]= new double[3* width]; 
    pic.open("test_ludzie.txt");
    
    if (pic.is_open()){
        while(!pic.eof()){
            if(counterj<3*width){
                pic >> picture[counteri][counterj];
                pic >> picture[counteri][counterj+1];
                pic >> picture[counteri][counterj+2];
                counterj+=3;
            }
            else{
                counterj = 0;
                counteri++;
                //pic >> picture[counteri][counterj];
            }
        }
    }    
    else{
            cout<<"Error! Nie udało się odczytać pliku!\n";
            return 0;
    }
    pic.close();
    
    //grayscaling image
    ofstream out;
    out.open("out_ludzie.txt");
    int **graypicture = new int*[height];
    for(int i =0;i<height;i++) graypicture[i] = new int[width];
    auto t_start = std::chrono::high_resolution_clock::now();
    graypicture = grayscale(picture, height, width);

    int thumbheight = 300;
    int thumbwidth = 300;

    int **outpicture = new int*[thumbheight];
    for(int i =0;i<thumbwidth;i++) outpicture[i] = new int[thumbwidth];
    
    outpicture = myresize(graypicture, height, width, thumbheight, thumbwidth);
    for(int i=0;i<thumbheight;i++){
        for(int j=0;j<thumbwidth;j++){
            out << outpicture[i][j] << "\t";
            //cout<<outpicture[i][j]<<'\t';
        }
        out << "\n";
        //cout<<'\n';
    }
    out.close();
    auto t_end = std::chrono::high_resolution_clock::now();
    double elapsed_time_ms = std::chrono::duration<double, std::milli>(t_end-t_start).count();
    time_cpu << elapsed_time_ms << '\n';
    time_cpu.close();


    for(int i=0;i<thumbheight;i++) delete[] outpicture[i];
    delete [] outpicture;

    for(int i=0;i<height;i++) delete[] graypicture[i];
    delete [] graypicture;

    return 0;
}

