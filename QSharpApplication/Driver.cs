using Microsoft.Quantum.Simulation.Core;
using Microsoft.Quantum.Simulation.Simulators;
using System;
using System.Threading.Tasks;
using static System.Console;

namespace Quantum.QSharpApplication
{
    class Driver
    {
        static async Task Main(string[] args)
        {
            while (true)
            {
                var simu = new QuantumSimulator(throwOnReleasingQubitsNotInZeroState: false);

                //var (q1, q2, res) = await QuantumXor.Run(simu);

                //WriteLine($"{q1}^{q2}={res}");

                var a = int.Parse(ReadLine());
                while (true)
                {
                    var (found, preImage) = await FindPreImage.Run(simu, a);
                    WriteLine($"Hash({preImage}){(found?'=':'!')}={a}");
                    if (found) break;
                }

                //var val = int.Parse(ReadLine());
                //var res = await BackAndForth.Run(simu, val, 4);
                //WriteLine(res);

            }
        }
    }
}