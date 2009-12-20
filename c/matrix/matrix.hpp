#ifndef MATRIX_HPP
#define MATRIX_HPP

#include <stdint.h>
#include <stdarg.h>
#include <exception>

template<typename T=float>
class Matrix
{
public:
    class DimensionException : public std::exception
    {
    public:
        DimensionException(){}
        ~DimensionException() throw() {}
        virtual const char* what() const throw()
        {
            return "matrix dimensions do not match";
        }
    };
    
    class Row
    {
    public:
        Row(Matrix<T> &matrix, uint16_t row) : matrix(matrix), row(row) {}
        ~Row(){}

        inline T& operator[](uint16_t col){ return matrix.Value(row,col); }

    private:
        Matrix<T> &matrix;
        uint16_t row;
    };

    Matrix(const Matrix& m);
    Matrix(uint16_t rows, uint16_t cols);
    ~Matrix();

    inline uint16_t Rows(){ return rows; }
    inline uint16_t Cols(){ return cols; }

    void Clear();

    inline T& Value(uint16_t row, uint16_t col){ return data[row][col]; }
    inline Row operator[](uint16_t row){ return Row(*this,row); }
    Matrix<T>& operator=(const Matrix<T> &m);
    Matrix<T>& operator()(uint16_t row,...);

    //Arithmetic Matrix Operations
    Matrix<T>& operator+=(const Matrix<T> &m) throw(DimensionException);
    Matrix<T>& operator-=(const Matrix<T> &m) throw(DimensionException);
    Matrix<T>& operator*=(const Matrix<T> &m) throw(DimensionException);
    Matrix<T>& operator/=(const Matrix<T> &m) throw(DimensionException);
    
    Matrix<T> operator+(const Matrix<T> &m) throw(DimensionException);
    Matrix<T> operator-(const Matrix<T> &m) throw(DimensionException);
    Matrix<T> operator*(const Matrix<T> &m) throw(DimensionException);
    Matrix<T> operator/(const Matrix<T> &m) throw(DimensionException);

    //Arithmetic Constant Operations
    Matrix<T>& operator+=(T val);
    Matrix<T>& operator-=(T val);
    Matrix<T>& operator*=(T val);
    Matrix<T>& operator/=(T val);
    
    Matrix<T> operator+(T val);
    Matrix<T> operator-(T val);
    Matrix<T> operator*(T val);
    Matrix<T> operator/(T val);
    
    Matrix<T> operator-();

    //Other Matrix Operations
    Matrix<T> ElementMult(const Matrix<T> &m) throw(DimensionException);
    
    T Determinant() throw(DimensionException);
    Matrix<T> Inverse() throw(DimensionException);
    Matrix<T> Transpose();
    
    inline T Det() throw(DimensionException) { return Determinant(); }
    inline Matrix<T> Inv() throw(DimensionException) { return Inverse(); }
    inline Matrix<T> Trans() { return Transpose(); }

    T Trace();

private:
    uint16_t rows;
    uint16_t cols;
    T **data;

    void Resize(uint16_t rows, uint16_t cols);
    void Free();

    T Minor(uint16_t row, uint16_t col);
    Matrix<T> Submatrix(uint16_t row, uint16_t col,
                         uint16_t rows, uint16_t cols);
    void SetSubmatrix(const Matrix<T> &m,
                      uint16_t row, uint16_t col,
                      uint16_t rows, uint16_t cols);
};

template<typename T>
Matrix<T>::Matrix(const Matrix& m)
{
    data=NULL;
    (*this)=m;
}

template<typename T>
Matrix<T>::Matrix(uint16_t rows, uint16_t cols)
{
    data=NULL;
    Resize(rows,cols);
}

template<typename T>
Matrix<T>::~Matrix()
{
    Free();
}

template<typename T>
void Matrix<T>::Clear()
{
    for(uint16_t i=0;i<rows;i++)
    {
        memset(data[i],0,cols*sizeof(T));
    }
}

template<typename T>
Matrix<T>& Matrix<T>::operator=(const Matrix<T> &m)
{
    if(m.rows!=rows || m.cols!=cols)
    {
        Resize(m.rows,m.cols);
    }

    //Copy data from each row.
    for(uint16_t i=0;i<rows;i++)
    {
        memcpy(data[i],m.data[i],cols*sizeof(T));
    }

    return *this;
}

template<typename T>
Matrix<T>& Matrix<T>::operator()(uint16_t row,...)
{
    if(row<rows)
    {
        va_list args;
        va_start(args,row);
        for(uint16_t i=0;i<cols;i++)
        {
            data[row][i]=static_cast<T>(va_arg(args,double));
        }
        va_end(args);
    }
    return *this;
}

template<typename T>
Matrix<T>& Matrix<T>::operator+=(const Matrix<T> &m) throw(DimensionException)
{
    if(m.rows!=rows || m.cols!=cols)throw DimensionException();
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            data[i][j]+=m.data[i][j];
        }
    }

    return *this;
}

template<typename T>
Matrix<T>& Matrix<T>::operator-=(const Matrix<T> &m) throw(DimensionException)
{
    if(m.rows!=rows || m.cols!=cols)throw DimensionException();
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            data[i][j]-=m.data[i][j];
        }
    }

    return *this;
}

template<typename T>
Matrix<T>& Matrix<T>::operator*=(const Matrix<T> &m) throw(DimensionException)
{
    if(cols!=m.rows)throw DimensionException();

    (*this)=(*this)*m;
    return *this;
}

template<typename T>
Matrix<T>& Matrix<T>::operator/=(const Matrix<T> &m) throw(DimensionException)
{
    if(m.rows!=rows || m.cols!=cols)throw DimensionException();
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            data[i][j]/=m.data[i][j];
        }
    }

    return *this;
}

template<typename T>
Matrix<T> Matrix<T>::operator+(const Matrix<T> &m) throw(DimensionException)
{
    if(m.rows!=rows || m.cols!=cols)throw DimensionException();

    Matrix<T> ret(rows,cols);
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            ret.data[i][j]=data[i][j]+m.data[i][j];
        }
    }

    return ret;
}

template<typename T>
Matrix<T> Matrix<T>::operator-(const Matrix<T> &m) throw(DimensionException)
{
    if(m.rows!=rows || m.cols!=cols)throw DimensionException();

    Matrix<T> ret(rows,cols);
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            ret.data[i][j]=data[i][j]-m.data[i][j];
        }
    }

    return ret;
}

template<typename T>
Matrix<T> Matrix<T>::operator*(const Matrix<T> &m) throw(DimensionException)
{
    if(cols!=m.rows)throw DimensionException();

    Matrix<T> ret(rows,m.cols);
    ret.Clear();
    
    for(uint16_t r=0;r<rows;r++)
    {
        for(uint16_t c=0;c<m.cols;c++)
        {
            for(uint16_t i=0;i<cols;i++)
            {
                ret.data[r][c]+=data[r][i]*m.data[i][c];
            }
        }
    }

    return ret;
}

template<typename T>
Matrix<T> Matrix<T>::operator/(const Matrix<T> &m) throw(DimensionException)
{
    if(m.rows!=rows || m.cols!=cols)throw DimensionException();

    Matrix<T> ret(rows,cols);
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            ret.data[i][j]=data[i][j]/m.data[i][j];
        }
    }

    return ret;
}

template<typename T>
Matrix<T>& Matrix<T>::operator+=(T val)
{
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            data[i][j]+=val;
        }
    }

    return *this;
}

template<typename T>
Matrix<T>& Matrix<T>::operator-=(T val)
{
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            data[i][j]-=val;
        }
    }

    return *this;
}

template<typename T>
Matrix<T>& Matrix<T>::operator*=(T val)
{
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            data[i][j]*=val;
        }
    }

    return *this;
}

template<typename T>
Matrix<T>& Matrix<T>::operator/=(T val)
{
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            data[i][j]/=val;
        }
    }

    return *this;
}

template<typename T>
Matrix<T> Matrix<T>::operator+(T val)
{
    Matrix<T> ret(rows,cols);
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            ret.data[i][j]=data[i][j]+val;
        }
    }

    return ret;
}

template<typename T>
Matrix<T> Matrix<T>::operator-(T val)
{
    Matrix<T> ret(rows,cols);
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            ret.data[i][j]=data[i][j]-val;
        }
    }

    return ret;
}

template<typename T>
Matrix<T> Matrix<T>::operator*(T val)
{
    Matrix<T> ret(rows,cols);
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            ret.data[i][j]=data[i][j]*val;
        }
    }

    return ret;
}

template<typename T>
Matrix<T> Matrix<T>::operator/(T val)
{
    Matrix<T> ret(rows,cols);
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            ret.data[i][j]=data[i][j]/val;
        }
    }

    return ret;
}

template<typename T>
Matrix<T> Matrix<T>::operator-()
{
    Matrix<T> ret(rows,cols);
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            ret.data[i][j]=-data[i][j];
        }
    }

    return ret;
}

template<typename T>
Matrix<T> Matrix<T>::ElementMult(const Matrix<T> &m) throw(DimensionException)
{
    if(m.rows!=rows || m.cols!=cols)throw DimensionException();

    Matrix<T> ret(rows,cols);
    
    for(uint16_t i=0;i<rows;i++)
    {
        for(uint16_t j=0;j<cols;j++)
        {
            ret.data[i][j]=data[i][j]*m.data[i][j];
        }
    }

    return ret;
}

template<typename T>
T Matrix<T>::Determinant() throw(DimensionException)
{
    if(rows!=cols)throw DimensionException();

    T det;

    if(rows==1)det=data[0][0];
    // | a b |
    // | c d |
    // det=ad-bc
    else if(rows==2)det=data[0][0]*data[1][1]-data[0][1]*data[1][0];
    // | a b c |
    // | d e f |
    // | g h i |
    // det=aei-afh-bdi+bfg+cdh-ceg
    else if(rows==3)
    {
        det=data[0][0]*data[1][1]*data[2][2]
            -data[0][0]*data[1][2]*data[2][1]
            -data[0][1]*data[1][0]*data[2][2]
            +data[0][1]*data[1][2]*data[2][0]
            +data[0][2]*data[1][0]*data[2][1]
            -data[0][2]*data[1][1]*data[2][0];
    }
    // det=SUM{j=1..n}(A[i,j](-1)^(i+j)M[i,j])
    else
    {
        int sign=1;
        det=0;
        for(uint16_t i=0;i<cols;i++)
        {
            if(sign==1)det+=data[0][i]*Minor(0,i);
            else det-=data[0][i]*Minor(0,i);
            sign=-sign;
        }
    }

    return det;
}

template<typename T>
Matrix<T> Matrix<T>::Inverse() throw(DimensionException)
{
    if(rows!=cols)throw DimensionException();

    Matrix<T> inv(rows,cols);

    if(rows==1)inv.data[0][0]=1/data[0][0];
    // | d -b |
    // | -c a |
    // --------
    //   |A|
    else if(rows==2)
    {
        inv.data[0][0]=data[1][1];
        inv.data[0][1]=-data[0][1];
        inv.data[1][0]=-data[1][0];
        inv.data[1][1]=data[0][0];
        inv/=Determinant();
    }
    else
    {
        uint16_t lwidth=rows/2;
        if(rows&0x01)lwidth+=1;
        uint16_t rwidth=rows-lwidth;

        Matrix<T> a=Submatrix(0,0,lwidth,lwidth);
        Matrix<T> b=Submatrix(0,lwidth,lwidth,rwidth);
        Matrix<T> c=Submatrix(lwidth,0,rwidth,lwidth);
        Matrix<T> d=Submatrix(lwidth,lwidth,rwidth,rwidth);

        Matrix<T> aInv=a.Inverse();
        
        //Schur complement = (D-CA^-1B)^-1
        Matrix<T> schur=aInv;
        schur=schur*b;
        schur=c*schur;
        schur=d-schur;
        schur=schur.Inverse();

        Matrix<T> schur_c_ainv=schur*c*aInv;
        
        Matrix<T> sub=aInv+aInv*b*schur_c_ainv;
        inv.SetSubmatrix(sub,0,0,lwidth,lwidth);
        sub=-aInv*b*schur;
        inv.SetSubmatrix(sub,0,lwidth,lwidth,rwidth);
        sub=-schur_c_ainv;
        inv.SetSubmatrix(sub,lwidth,0,rwidth,lwidth);
        inv.SetSubmatrix(schur,lwidth,lwidth,rwidth,rwidth);
    }

    return inv;
}

template<typename T>
Matrix<T> Matrix<T>::Transpose()
{
    Matrix<T> ret(cols,rows);
    
    for(uint16_t r=0;r<rows;r++)
    {
        for(uint16_t c=0;c<cols;c++)
        {
            ret.data[c][r]=data[r][c];
        }
    }

    return ret;
}

template<typename T>
T Matrix<T>::Trace()
{
    T trace=0;
    for(uint16_t i=0;i<rows && i<cols;i++)
    {
        trace+=data[i][i];
    }
    return trace;
}

template<typename T>
void Matrix<T>::Resize(uint16_t rows, uint16_t cols)
{
    Free();
    
    this->rows=rows;
    this->cols=cols;

    //Allocate data array.
    data=new T*[rows];
    for(uint16_t i=0;i<rows;i++)
    {
        data[i]=new T[cols];
    }
}

template<typename T>
void Matrix<T>::Free()
{
    if(data==NULL)return;
    
    //Free current data array.
    for(uint16_t i=0;i<rows;i++)
    {
        //free(data[i]);
        delete[] data[i];
    }
    //free(data);
    delete[] data;
}

template<typename T>
T Matrix<T>::Minor(uint16_t row, uint16_t col)
{
    uint16_t r, c;
    Matrix<T> minorMatrix(rows-1,cols-1);

    r=0;
    for(uint16_t i=0;i<rows;i++)
    {
        if(i==row)continue;
        
        c=0;
        for(uint16_t j=0;j<cols;j++)
        {
            if(j==col)continue;
            minorMatrix.data[r][c++]=data[i][j];
        }
        r++;
    }

    return minorMatrix.Determinant();
}

template<typename T>
void Matrix<T>::SetSubmatrix(const Matrix<T> &m,
                          uint16_t row, uint16_t col,
                          uint16_t rows, uint16_t cols)
{
    uint16_t endRow=row+rows;
    uint16_t endCol=col+cols;

    uint16_t sr=0;
    for(uint16_t r=row;r<endRow;r++)
    {
        uint16_t sc=0;
        for(uint16_t c=col;c<endCol;c++)
        {
            data[r][c]=m.data[sr][sc++];
        }
        sr++;
    }
}

template<typename T>
Matrix<T> Matrix<T>::Submatrix(uint16_t row, uint16_t col,
                               uint16_t rows, uint16_t cols)
{
    Matrix<T> ret(rows,cols);

    uint16_t endRow=row+rows;
    uint16_t endCol=col+cols;

    uint16_t sr=0;
    for(uint16_t r=row;r<endRow;r++)
    {
        uint16_t sc=0;
        for(uint16_t c=col;c<endCol;c++)
        {
            ret.data[sr][sc++]=data[r][c];
        }
        sr++;
    }

    return ret;
}

#endif
