using GPUifyLoops, Cthulhu, CuArrays, CUDAnative

kernel!(A::Array, B::Array) = kernel!(CPU(), Val(size(B,2)), A, B)
function kernel!(::Dev, ::Val{nbcol}, A, B) where {Dev, nbcol}
    @setup Dev
    @inbounds @loop for i in (1:size(A,1);
                              (blockIdx().x-1)*blockDim().x + threadIdx().x)
        a = zero(eltype(B))
        for j = 1:nbcol
            a += B[i, j]
        end
        A[i] = a
    end
    nothing
end

@eval function kernel!(A::CuArray, B::CuArray)
  threads = 1024
  blocks = ceil(Int, size(A,1)/threads)
  @cuda(threads=threads, blocks=blocks, kernel!(CUDA(), Val(size(B,2)), A, B))
end

b = rand(Float32, 10^8, 10)
a = similar(b, size(b,1))
cb = CuArray(a)
ca = similar(cb, size(b,1))

@static if isdefined(Base, :active_repl)
    # Example of how to decend using Cthulhu
    args = (CUDA(), Val(size(cb,2)), ca, cb)
    cuargs = map(cudaconvert, args)
    tt = map(typeof, cuargs)
    descend(kernel!, Tuple{tt...})
end

# Run the kernel
kernel!(ca, cb)
kernel!(ca, cb)
kernel!(ca, cb)
kernel!(ca, cb)

# Dump intermediate files into the tmp directory
@device_code dir="tmp" kernel!(ca, cb)