unit uClass_OpenCL;

interface



Uses
  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  CL_platform,
  CL,
  DelphiCL,
  StdCtrls;


Type
  PArrTCL_float = Array Of TCL_float;

  TOpenCL2In1Out = Class
  Private
    CommandQueue: TDCLCommandQueue;
    SimpleProgram: TDCLProgram;
    Kernel: TDCLKernel;
    InputBuffer1, InputBuffer2, OutputBuffer: TDCLBuffer;
    CLDevice: TDCLDevice;
  Public
    ExecuteTime: Integer;
    Input1, Input2, Output: ^PArrTCL_float;
    count: Integer;
    Size: Integer;
    Width, Height: Integer;

    Constructor create(sFunctionName: PAnsiChar; sFilename: String; Width,Height: Integer);
    Destructor Destroy;

    Procedure Execute;
  End;
implementation

Constructor TOpenCL2In1Out.create(sFunctionName: PAnsiChar; sFilename: String; Width,Height: Integer);
Begin
  self.Width := Width;
  self.Height := Height;
  self.count := Height*Height;
  self.Size := count * SizeOf(TCL_float);

  getmem(Input1, size);
  getmem(Input2, size);
  getmem(Output, size);

  InitOpenCL();
  CLDevice := TDCLPlatforms.create().Platforms[0].DeviceWithMaxClockFrequency;
  CommandQueue := CLDevice.CreateCommandQueue();

  InputBuffer1 := CLDevice.CreateBuffer(Size, @Input1^[0], [mfReadOnly, mfUseHostPtr]);
  InputBuffer2 := CLDevice.CreateBuffer(Size, @Input2^[0], [mfReadOnly, mfUseHostPtr]);
  OutputBuffer := CLDevice.CreateBuffer(Size, Nil, [mfWriteOnly]);

  If CLDevice.Status <> 0 Then
    showmessage('CLDevice Status:' + GetString(CLDevice.Status));

  SimpleProgram := CLDevice.CreateProgram(sFilename);

  If SimpleProgram.Status <> 0 Then
    showmessage('Program Status:' + GetString(SimpleProgram.Status));

  Kernel := SimpleProgram.CreateKernel(sFunctionName);

  If Kernel.Status <> 0 Then
    showmessage('Kernel Status:' + GetString(Kernel.Status));

  Kernel.SetArg(0, InputBuffer1);
  Kernel.SetArg(1, InputBuffer2);
  Kernel.SetArg(2, OutputBuffer);
  Kernel.SetArg(3, sizeof(Width), @Width);
  Kernel.SetArg(4, sizeof(Height), @Height);
End;

Destructor TOpenCL2In1Out.Destroy;
Begin
  Kernel.Free();
  SimpleProgram.Free();
  OutputBuffer.Free();
  InputBuffer1.Free();
  InputBuffer2.Free();
  CommandQueue.Free();
  CLDevice.Free();

  Freemem(Input1);
  Freemem(Input2);
  Freemem(Output);

End;

Procedure TOpenCL2In1Out.Execute;
Begin

  CommandQueue.WriteBuffer(InputBuffer1, Size, @Input1^[0]);
  CommandQueue.WriteBuffer(InputBuffer2, Size, @Input2^[0]);
  CommandQueue.Execute(Kernel, Width * Height);
  ExecuteTime := CommandQueue.ExecuteTime;
  CommandQueue.ReadBuffer(OutputBuffer, Size, @Output^[0]);

End;
end.
 