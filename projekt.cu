#include <iostream>
#include <fstream>

using namespace std;

#define THREADS 32

__global__ void gray_cuda(const double *rgbpic_flat_r, const double *rgbpic_flat_g, const double *rgbpic_flat_b, double *picture_flat, const int height, const int width){

    int row = blockIdx.x * blockDim.x + threadIdx.x;
    int col = blockIdx.y * blockDim.y + threadIdx.y;
    //__syncthreads();
    // int suma1 = 0;
    // int suma2 = 0;
    // int suma3 = 0;
    if (row < height && col < width){   //zle, zrobić osobne macierze dla każdego koloru
        // __syncthreads();
        // suma1 = 0.2627 * rgbpic_flat_r[(row*width) + col];  
        // suma2 = 0.6780 * rgbpic_flat_g[(row*width) + col];
        // suma3 = 0.0593 * rgbpic_flat_b[(row*width) + col];
        picture_flat[(row*width) + col] =  0.2627 * rgbpic_flat_r[(row*width) + col] + 0.6780 * rgbpic_flat_g[(row*width) + col] + 0.0593 * rgbpic_flat_b[(row*width) + col];
    }
}

__global__ void resize_cuda_kernel(const int *picture, int *smolpicture, const int height, const int width, const int xscale, const int yscale, const int thumbheight, const int thumbwidth){

    int row = blockIdx.x * blockDim.x + threadIdx.x;
    int col = blockIdx.y * blockDim.y + threadIdx.y;

    int sum = 0;
    int amount = xscale * yscale;

    if (row < thumbheight && col < thumbwidth){
        for(int f = 0; f < xscale; ++f){
            for(int g = 0; g < yscale; ++g){
                if(row*(xscale-1) + f < height && col*(yscale-1) + g < width){
                    
                    sum += picture[((row*(xscale-1) + f) * width) + (col*(yscale-1) + g)];
                }
            }
        }
        smolpicture[(row*thumbwidth) + col] = sum/amount;
        sum = 0;
    }
}



int **resize_cuda(int **picture, int height=960, int width=720, int thumbheight=120, int thumbwidth=120){

    // Zadeklarowanie pamięci dla tablicy mniejszego obrazka
    int **smolpicture = new int*[thumbheight];
    for(int i = 0; i<thumbheight;++i) smolpicture[i] = new int[thumbwidth];
    //skala okna do average pooling
    int xscale = 1 + height / thumbheight;
    int yscale = 1 + width / thumbwidth;
    // Obrazek w skali szarości, spłaszczony
    int *picture_flat = new int[height*width];
    int *picture_flat_d = new int[height*width];
    // Pomniejszony obrazek, spłaszczony
    int *smolpicture_flat = new int[thumbheight*thumbwidth];
    int *smolpicture_flat_d = new int[thumbheight*thumbwidth];

    size_t size1 = height*width*sizeof(int);
    size_t size2 = thumbheight*thumbwidth*sizeof(int);

    for(int i = 0; i < height; i++){
        for(int j=0; j < width; j++){
            picture_flat[(i*width) + j] = picture[i][j]; //spłaszczanie obrazka
        }    
    }
    //przygotowanie kernela
    cudaMalloc((void **)&picture_flat_d,size1);
    cudaMalloc((void **)&smolpicture_flat_d,size2);

    cudaMemcpy(picture_flat_d, picture_flat, size1, cudaMemcpyHostToDevice);

    dim3 threadsPerBlock(THREADS, THREADS);
    dim3 numBlocks(ceil(thumbheight/float(THREADS)), ceil(thumbwidth/float(THREADS)));

    resize_cuda_kernel<<<numBlocks, threadsPerBlock>>>(picture_flat_d, smolpicture_flat_d, height, width, xscale, yscale, thumbheight, thumbwidth);

    cudaMemcpy(smolpicture_flat, smolpicture_flat_d, size2, cudaMemcpyDeviceToHost);

    cudaFree(smolpicture_flat_d);
    cudaFree(picture_flat_d);

    //przepisanie wartości ze spłaszczonej tablicy do tablicy 2D
    for(int i = 0; i < thumbheight; i++){
        for(int j = 0; j < thumbwidth; j++){
            smolpicture[i][j] = smolpicture_flat[(i*thumbwidth) + j];
        }
    }

    //sprzątanie
    delete [] smolpicture_flat;
    delete [] picture_flat;

    cudaDeviceReset();

    return smolpicture;
}

int **grayscale_cuda(double **rgbpic, int height=960, int width=720){
    /*
    GraYSCALING NA CUDZIE
    */
    // Zadeklarowanie pamięci na szary obrazek
    int **picture;
    picture = new int* [height];
    for(int i = 0; i<height;++i) picture[i] = new int[width];
    double *picture_flat = new double[height*width];
    double *picture_flat_d = new double[height*width];
    //poszczególne kolory(spektrum RGB)
    double *rgbpic_flat_r = new double[height*width];
    double *rgbpic_flat_g = new double[height*width];
    double *rgbpic_flat_b = new double[height*width];
    //device copies
    double *rgbpic_flat_d_r = new double[height*width];
    double *rgbpic_flat_d_g = new double[height*width];
    double *rgbpic_flat_d_b = new double[height*width];
    
    size_t size2 = height*width*sizeof(double);

    for(int i = 0; i < height; i++){
        for(int j=0; j < 3 * width; j+=3){
            rgbpic_flat_r[(i*width)+ j/3] = rgbpic[i][j]; //"spłaszczanie" tablic
            rgbpic_flat_g[(i*width)+ j/3] = rgbpic[i][j+1]; //"spłaszczanie" tablic
            rgbpic_flat_b[(i*width)+ j/3] = rgbpic[i][j+2]; //"spłaszczanie" tablic     
       }    
    }

    //przygotowanie kernela
    cudaMalloc((void **)&picture_flat_d,size2);
    cudaMalloc((void **)&rgbpic_flat_d_r,size2);
    cudaMalloc((void **)&rgbpic_flat_d_g,size2);
    cudaMalloc((void **)&rgbpic_flat_d_b,size2);


    cudaMemcpy(rgbpic_flat_d_r, rgbpic_flat_r, size2, cudaMemcpyHostToDevice);
    cudaMemcpy(rgbpic_flat_d_g, rgbpic_flat_g, size2, cudaMemcpyHostToDevice);
    cudaMemcpy(rgbpic_flat_d_b, rgbpic_flat_b, size2, cudaMemcpyHostToDevice);


    dim3 threadsPerBlock(THREADS, THREADS);
    dim3 numBlocks(ceil(height/float(THREADS)), ceil(width/float(THREADS)));
    gray_cuda<<<numBlocks, threadsPerBlock>>>(rgbpic_flat_d_r, rgbpic_flat_d_g, rgbpic_flat_d_b, picture_flat_d, height, width);

    cudaMemcpy(picture_flat, picture_flat_d, size2, cudaMemcpyDeviceToHost);

    cudaFree(rgbpic_flat_d_r); 
    cudaFree(rgbpic_flat_d_g); 
    cudaFree(rgbpic_flat_d_b);
    cudaFree(picture_flat_d); 

    //przepisanie wartości ze spłaszczonej tablicy do tablicy 2D
    for(int i = 0; i < height; i++){
        for(int j = 0; j < width; j++){
            picture[i][j] = picture_flat[(i*width) + j];
        }
    }

    //sprzątanie
    delete [] picture_flat;
    delete [] rgbpic_flat_r;
    delete [] rgbpic_flat_g;
    delete [] rgbpic_flat_b;

    cudaDeviceReset();

    return picture;
}

int main(){
    
    fstream pic;
    fstream wymiary;
    int counteri = 0;
    int counterj = 0;
    // Wczytywać wysokośc i szerokośc z pliku z pythona, thumb też -----------TODO
    int height = 960;
    int width = 720;
    wymiary.open("wymiary.txt", 'r');
    wymiary >> height;
    wymiary >> width;
    wymiary.close();

    double **picture = new double*[height];
    for(int i=0;i<height;i++) picture[i]= new double[3* width]; 
    pic.open("test.txt");
    // zczytanie z pliku wygenerowanego z pythona do tablicy obrazka RGB
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
            }
        }
    }    
    else{
            cout<<"Error! Nie udało się odczytać pliku!\n";
            return 0;
    }
    pic.close();

    // Otwarcie pliku do zapisu ostatecznego obrazka
    ofstream outcuda;
    outcuda.open("outcuda.txt");
    int **graypicture = new int*[height];
    for(int i =0;i<height;i++) graypicture[i] = new int[width];
    graypicture = grayscale_cuda(picture, height, width); // RGB -> GRAYSCALE

    // To do wczytanie z pliku z pythona
    int thumbheight = 120;
    int thumbwidth = 120;

    int **outpicture = new int*[thumbheight];
    for(int i =0;i<thumbheight;i++) outpicture[i] = new int[thumbwidth];
    
    outpicture = resize_cuda(graypicture, height, width, thumbheight, thumbwidth); //DUŻY -> MNIEJSZY
    for(int i=0;i<thumbheight;i++){
        for(int j=0;j<thumbwidth;j++){
            outcuda << outpicture[i][j] << '\t';
        }
        outcuda << "\n";
    }
    outcuda.close();

    for(int i=0;i<thumbheight;i++) delete[] outpicture[i];
    delete [] outpicture;

    for(int i=0;i<height;i++) delete[] graypicture[i];
    delete [] graypicture;

    return 0;
}

