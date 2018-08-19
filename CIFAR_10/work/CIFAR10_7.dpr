program CIFAR10_7;

uses
  Forms, 
  uFRMMain in 'uFRMMain.pas' {FRMMain},
  uClass_CNN in '..\..\Common\uClass_CNN.pas',
  uClass_Imaging in '..\..\Common\uClass_Imaging.pas',
  uClasses_Types in '..\..\Common\uClasses_Types.pas',
  uFunctions in '..\..\Common\uFunctions.pas',
  dglOpenGL in '..\..\Common\OpenCL\dglOpenGL.pas',
  CL in '..\..\Common\OpenCL\OpenCL\CL.pas',
  CL_platform in '..\..\Common\OpenCL\OpenCL\CL_platform.pas',
  DelphiCL in '..\..\Common\OpenCL\OpenCL\DelphiCL.pas',
  uClass_OpenCL in '..\..\Common\uClass_OpenCL.pas'
  ;

{$R *.res}

begin

  Application.Initialize;
  Application.CreateForm(TFRMMain, FRMMain);
  Application.Run;
end.
