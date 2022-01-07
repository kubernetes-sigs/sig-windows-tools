using Microsoft.Diagnostics.EventFlow;
using System.Text.Json;
using System.Text.Json.Nodes;

string configFilePath = "eventFlowConfig.json";
if (args.Length > 0)
{
    configFilePath = args[0];
}
Console.WriteLine($"Using configuration file {configFilePath}:");
var configuration = File.ReadAllText(configFilePath);
Console.WriteLine($"{configuration}");

using (ManualResetEvent terminationEvent = new ManualResetEvent(initialState: false))
using (var pipeline = DiagnosticPipelineFactory.CreatePipeline(configFilePath))
{
    Console.CancelKeyPress += (sender, eventArgs) => Shutdown(pipeline, terminationEvent);
    Console.WriteLine("Logging started...");
    terminationEvent.WaitOne();
}

void Shutdown(IDisposable disposable, ManualResetEvent terminationEvent)
{
    try
    {
        disposable.Dispose();
    }
    finally
    {
        terminationEvent.Set();
    }
}
