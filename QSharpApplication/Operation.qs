namespace Quantum.QSharpApplication
{
    open Microsoft.Quantum.Primitive;
    open Microsoft.Quantum.Canon;

    operation QuantumXor () : (Result, Result, Result)
    {
        body
        {
			mutable m1 = Zero;
			mutable m2 = Zero;
			mutable mRes = Zero;

            using (qubits = Qubit[3])
			{
				let q1 = qubits[0];
				let q2 = qubits[1];
				let res = qubits[2];

				// superpose q1
				H(q1);
				// superpose 2
				H(q2);

				Xor(q1, q2, res);

				// res is now supposed to be q1^q2
				// let check it
				set m1 = M(q1);
				set m2 = M(q2);
				set mRes = M(res);
			}

			return (m1, m2, mRes);
        }
    }

	operation Xor (a : Qubit , b : Qubit, res: Qubit) : ()
	{
		body
		{
			CNOT(a, res);
			CNOT(b, res);
		}
	}

	operation RandomAdd (value : Int, nQubits : Int) : (Int, Int)
	{
		body
		{
			mutable operand = 0;
			mutable sum = 0;
			using (values = Qubit[nQubits*2])
			{
				let a = values[0..nQubits-1];
				let b = values[nQubits..2*nQubits-1];
				// encode a to our qubits
				Encode (value, a);
				// superpose all values to b expected last not to overflow
				for (i in 1..nQubits-1)
				{
					H(b[i]);
				}
				Add(b, a);
				set sum = Decode(a);
				set operand = Decode(b);
			}

			return (operand, sum);
		}
	}

	// encode int to LE qubits
	operation Encode (value : Int, res : Qubit[]) : ()
	{
		body
		{
			mutable v = value;
			for (i in 0..Length(res) - 1)
			{
				let pos = Length(res) - 1 - i;
				if (v % 2 == 1)
				{
					if (M(res[pos]) == Zero)
					{
						X(res[pos]);
					}
				}
				else
				{
					if (M(res[pos]) == One)
					{
						X(res[pos]);
					}
				}
				set v = v / 2;
			}
		}
	}

	// Decode LE qbits to int
	operation Decode (value : Qubit[]) : Int
	{
		body
		{
			mutable result = 0;
			for (i in 0..Length(value)-1)
			{
				set result = result * 2;
				if (M(value[i]) == One)
				{
					set result = result + 1;
				}
			}
			return result;
		}
	}

	/// wipe the current qbit after untangle it
	/// !!! it is not controllable, but declared as if it was to make callers controllable
	operation Wipe(q : Qubit) : ()
	{
		body
		{
			// hadamar untangles it from anywhere
			H(q);
			if (M(q) == One)
			{
				X(q);
			}
		}

		// not really controlled, but that's only for a buffer qubit
		controlled (controls)
		{
			// hadamar untangles it from anywhere
			H(q);
			if (M(q) == One)
			{
				X(q);
			}
		}
	}

	operation BackAndForth(a : Int, n : Int) : Int
	{
		body
		{
			mutable decoded = 0;
			using (v = Qubit[n])
			{
				Encode(a, v);
				set decoded = Decode(v);
			}
			return decoded;
		}
	}

	/// add the LE encoded value a and b, and store the result in b
	operation Add (a : Qubit[], b : Qubit[]) : ()
	{
		body
		{
			using (c = Qubit[2])
			{
				let (acc, carry) = (c[0], c[1]);

				for (i in 0..Length(b)-1)
				{
					let bi = b[Length(b) - 1 - i];

					if (i < Length(a))
					{
						let ai = a[Length(a)-1 - i];

						// report a carry if b == 1 and a == 1
						CCNOT(bi, ai, acc);
						// invert b if a == 1
						CNOT(ai, bi);
					}

					// set next carry (acc) if b and carry are set
					// NOTE: acc and b are not supposed to be set at the same time
					CCNOT(bi, carry, acc);
					// move the carry the b
					CNOT(carry, bi);
					// move the next carry to the carry qubit
					SWAP(carry, acc);
					// clear the accumulator for the next iteration
					Wipe(acc);
				}
			}
		}

		// this will be usefull for multiplication
		controlled auto;
	}
	
	// encode int to LE results
	operation EncodeToResult (value : Int, n : Int) : Result[]
	{
		body
		{
			mutable v = value;
			mutable res = new Result[n];
			for (i in 0..n - 1)
			{
				let pos = n - 1 - i;
				if (v % 2 == 1)
				{
					set res[pos] = One;
				}
				else
				{
					set res[pos] = Zero;
				}
				set v = v / 2;
			}
			return res;
		}
	}

	/// invert res when x and y are equals
	/// will destroy the state of y (but could be easily restored)
	operation AreEqual(x : Int, y : Qubit[], res : Qubit) : ()
	{
		body
		{
			let encodedX = EncodeToResult(x, Length(y));
			// flip all expected |0>, to have only |1> when equals
			FlipWhenEquals(encodedX, y);
			// when all y is |1>, set res to |1>, else set to |0>
			(Controlled X) (y, res);
			// could re-flip y here if needed to keep the state of y
			// (Adjoint FlipWhenEquals) (encodedX, y);
		}
	}

	operation FlipWhenEquals(x : Result[], y : Qubit[]) : ()
	{
		body
		{
			// flip all expected |0>, to have only |1> when equals
			for (i in 0..Length(y)-1)
			{
				let (xi, yi) = (x[i], y[i]);
				if (xi == Zero)
				{
					X(yi);
				}
			}
		}

		adjoint self;
		controlled auto;
		adjoint controlled auto;
	}

	operation MulI (a : Int, b : Qubit[], output : Qubit[]) : ()
	{
		body
		{
			let aEnc = EncodeToResult(a, Length(b));
			for (pos in 0..Length(aEnc)-1)
			{
				if (aEnc[Length(aEnc)-1-pos] == One)
				{
					Add (b, output[0..Length(output)-1-pos]);
				}
			}
		}
	}

	operation Mul (a : Qubit[], b : Qubit[], output : Qubit[]) : ()
	{
		body
		{
			for (i in 0..Length(a)-1)
			{
				let pos = Length(a)-1-i;
				(Controlled Add) ([a[pos]], (b, output[0..Length(output)-1-i]));
			}
		}
	}

	operation MulAB (va : Int, vb : Int, nQubits : Int) : (Int)
	{
		body
		{
			mutable operand = 0;
			mutable product = 0;
			using (values = Qubit[nQubits*2])
			{
				let res = values[0..nQubits-1];
				let b = values[nQubits..2*nQubits-1];

				Encode(vb, b);

				MulI(va, b, res);
				set product = Decode(res);
				set operand = Decode(b);
			}

			return (product);
		}
	}

	operation RandomMul (value : Int, nQubits : Int) : (Int, Int)
	{
		body
		{
			mutable operand = 0;
			mutable sum = 0;
			using (values = Qubit[nQubits*2])
			{
				let res = values[0..nQubits-1];
				let b = values[nQubits..2*nQubits-1];

				// superpose all values to b
				for (i in 1..nQubits-1)
				{
					H(b[i]);
				}

				MulI(value, b, res);
				set sum = Decode(res);
				set operand = Decode(b);
			}

			return (operand, sum);
		}
	}

	/// The best unreversable hash function ever!
	operation Hash(value : Qubit[], result : Qubit[]) : ()
	{
		body
		{
			// 61 is the largest prime < 2^6, should be a good candidate for our hash function on 6 bits
			let prime = 61;
			MulI(prime, value, result);
		}
	}

	operation FindPreImage(value : Int) : (Bool, Int)
	{
		body
		{
			let nQubits = 6;
			mutable preImage = 0;
			mutable preImageFound = false;
			using (register = Qubit[2*nQubits+1])
			{
				let candidate = register[0..nQubits-1];
				let result = register[nQubits..2*nQubits-1];
				let found = register[2*nQubits];

				// first superpose our candidates
				for (i in 0..nQubits-1)
				{
					H(candidate[i]);
				}
				// then hash the candidates
				Hash(candidate, result);
				// spot the candidates (the ones for which found = |1>)
				AreEqual(value, result, found);
				// collapse the whole thing
				if (One == M(found))
				{
					set preImageFound = true;
				}
				set preImage = Decode(candidate);
			}
			return (preImageFound, preImage);
		}
	}
}
