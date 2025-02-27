// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Foundation.NoSeries;

codeunit 281 NoSeriesMgt
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;
    Permissions =
        tabledata "No. Series" = r,
        tabledata "No. Series Line" = rimd;

    var
        NumberLengthErr: Label 'The number %1 cannot be extended to more than 20 characters.', Comment = '%1=No.';
        NumberFormatErr: Label 'The number format in %1 must be the same as the number format in %2.', Comment = '%1=No. Series Code,%2=No. Series Code';
        UnIncrementableStringErr: Label 'The value in the %1 field must have a number so that we can assign the next number in the series.', Comment = '%1 = New Field Name';
        NoOverFlowErr: Label 'Number series can only use up to 18 digit numbers. %1 has %2 digits.', Comment = '%1 is a string that also contains digits. %2 is a number.';

    internal procedure UpdateNoSeriesLine(var NoSeriesLine: Record "No. Series Line"; NewNo: Code[20]; NewFieldName: Text[100])
    var
        NoSeriesLine2: Record "No. Series Line";
#pragma warning disable AL0432
        NoSeriesManagement: Codeunit NoSeriesManagement;
#pragma warning restore AL0432
        Length: Integer;
        IsHandled: Boolean;
    begin
        IsHandled := false;
        NoSeriesManagement.OnBeforeUpdateNoSeriesLine(NoSeriesLine, NewNo, NewFieldName, IsHandled);
        if IsHandled then
            exit;

        if NewNo <> '' then begin
            if IncStr(NewNo) = '' then
                Error(UnIncrementableStringErr, NewFieldName);
            NoSeriesLine2 := NoSeriesLine;
            if NewNo = GetNoText(NewNo) then
                Length := 0
            else begin
                Length := StrLen(GetNoText(NewNo));
                UpdateLength(NoSeriesLine."Starting No.", Length);
                UpdateLength(NoSeriesLine."Ending No.", Length);
                UpdateLength(NoSeriesLine."Last No. Used", Length);
                UpdateLength(NoSeriesLine."Warning No.", Length);
            end;
            UpdateNo(NoSeriesLine."Starting No.", NewNo, Length);
            UpdateNo(NoSeriesLine."Ending No.", NewNo, Length);
            UpdateNo(NoSeriesLine."Last No. Used", NewNo, Length);
            UpdateNo(NoSeriesLine."Warning No.", NewNo, Length);
            if (NewFieldName <> NoSeriesLine.FieldCaption("Last No. Used")) and
               (NoSeriesLine."Last No. Used" <> NoSeriesLine2."Last No. Used")
            then
                Error(
                  NumberFormatErr,
                  NewFieldName, NoSeriesLine.FieldCaption("Last No. Used"));
        end;
    end;

    internal procedure FindNoSeriesLineToShow(var NoSeries: Record "No. Series"; var NoSeriesLine: Record "No. Series Line")
    begin
        SetNoSeriesLineFilter(NoSeriesLine, NoSeries.Code, 0D);

        if NoSeriesLine.FindLast() then
            exit;

        NoSeriesLine.Reset();
        NoSeriesLine.SetRange("Series Code", NoSeries.Code);
    end;

    internal procedure SetNoSeriesLineFilter(var NoSeriesLine: Record "No. Series Line"; NoSeriesCode: Code[20]; StartDate: Date)
#if not CLEAN24
#pragma warning disable AL0432
    var
        NoSeriesManagement: Codeunit NoSeriesManagement;
#pragma warning restore AL0432
#endif
    begin
        if StartDate = 0D then
            StartDate := WorkDate();

        NoSeriesLine.Reset();
        NoSeriesLine.SetCurrentKey("Series Code", "Starting Date");
        NoSeriesLine.SetRange("Series Code", NoSeriesCode);
        NoSeriesLine.SetRange("Starting Date", 0D, StartDate);
#if not CLEAN24
#pragma warning disable AL0432
        NoSeriesManagement.RaiseObsoleteOnNoSeriesLineFilterOnBeforeFindLast(NoSeriesLine);
#pragma warning restore AL0432
#endif
        if NoSeriesLine.FindLast() then begin
            NoSeriesLine.SetRange("Starting Date", NoSeriesLine."Starting Date");
            NoSeriesLine.SetRange(Open, true);
        end;
    end;

#if not CLEAN24
#pragma warning disable AL0432
    internal procedure SetAllowGaps(var NoSeries: Record "No. Series"; AllowGaps: Boolean)
    var
        NoSeriesLine: Record "No. Series Line";
        StartDate: Date;
    begin
        FindNoSeriesLineToShow(NoSeries, NoSeriesLine);
        StartDate := NoSeriesLine."Starting Date";
        NoSeriesLine.SetRange("Allow Gaps in Nos.", not AllowGaps);
        NoSeriesLine.SetFilter("Starting Date", '>=%1', StartDate);
        NoSeriesLine.LockTable();
        if NoSeriesLine.FindSet() then
            repeat
                NoSeriesLine.Validate("Allow Gaps in Nos.", AllowGaps);
                NoSeriesLine.Modify();
            until NoSeriesLine.Next() = 0;
    end;
#pragma warning restore AL0432
#endif

    internal procedure ValidateDefaultNos(var NoSeries: Record "No. Series"; xRecNoSeries: Record "No. Series")
    var
        IsHandled: Boolean;
    begin
        IsHandled := false;
#if not CLEAN24
#pragma warning disable AL0432
        NoSeries.OnBeforeValidateDefaultNos(NoSeries, IsHandled);
#pragma warning restore AL0432
#endif
        if not IsHandled then
            if (NoSeries."Default Nos." = false) and (xRecNoSeries."Default Nos." <> NoSeries."Default Nos.") and (NoSeries."Manual Nos." = false) then
                NoSeries.Validate("Manual Nos.", true);
    end;

    internal procedure ValidateManualNos(var NoSeries: Record "No. Series"; xRecNoSeries: Record "No. Series")
    var
        IsHandled: Boolean;
    begin
        IsHandled := false;
#if not CLEAN24
#pragma warning disable AL0432
        NoSeries.OnBeforeValidateManualNos(NoSeries, IsHandled);
#pragma warning restore AL0432
#endif
        if not IsHandled then
            if (NoSeries."Manual Nos." = false) and (xRecNoSeries."Manual Nos." <> NoSeries."Manual Nos.") and (NoSeries."Default Nos." = false) then
                NoSeries.Validate("Default Nos.", true);
    end;

    internal procedure CreateNewSequence(var NoSeriesLine: Record "No. Series Line")
    begin
        if NoSeriesLine."Sequence Name" = '' then
            NoSeriesLine."Sequence Name" := Format(CreateGuid(), 0, 4);

        if NoSeriesLine."Last No. Used" = '' then
            NumberSequence.Insert(NoSeriesLine."Sequence Name", NoSeriesLine."Starting Sequence No." - NoSeriesLine."Increment-by No.", NoSeriesLine."Increment-by No.")
        else begin
            NumberSequence.Insert(NoSeriesLine."Sequence Name", NoSeriesLine."Starting Sequence No.", NoSeriesLine."Increment-by No.");
            if NumberSequence.Next(NoSeriesLine."Sequence Name") = 0 then;  // Simulate that a number was used
        end;
    end;

    internal procedure RestartSequence(var NoSeriesLine: Record "No. Series Line"; NewStartingNo: BigInteger)
    begin
        NoSeriesLine.TestField(Implementation, NoSeriesLine.Implementation::Sequence);
        NoSeriesLine.TestField("Sequence Name");
        NoSeriesLine."Starting Sequence No." := NewStartingNo;
        if NoSeriesLine."Last No. Used" = '' then
            NumberSequence.Restart(NoSeriesLine."Sequence Name", NoSeriesLine."Starting Sequence No." - NoSeriesLine."Increment-by No.")
        else begin
            NumberSequence.Restart(NoSeriesLine."Sequence Name", NoSeriesLine."Starting Sequence No.");
            if NumberSequence.Next(NoSeriesLine."Sequence Name") = 0 then;  // Simulate that a number was used
        end;
    end;

    internal procedure UpdateStartingSequenceNo(var NoSeriesLine: Record "No. Series Line")
    begin
        if not (NoSeriesLine.Implementation = "No. Series Implementation"::Sequence) then
            exit;

        if NoSeriesLine."Last No. Used" = '' then
            NoSeriesLine."Starting Sequence No." := ExtractNoFromCode(NoSeriesLine."Starting No.")
        else
            NoSeriesLine."Starting Sequence No." := ExtractNoFromCode(NoSeriesLine."Last No. Used");
    end;

    internal procedure RecreateSequence(var NoSeriesLine: Record "No. Series Line")
    var
        NoSeries: Codeunit "No. Series";
    begin
        if NoSeriesLine."Last No. Used" = '' then
            NoSeriesLine."Last No. Used" := NoSeries.GetLastNoUsed(NoSeriesLine);
        DeleteSequence(NoSeriesLine);
        UpdateStartingSequenceNo(NoSeriesLine);
        CreateNewSequence(NoSeriesLine);
        NoSeriesLine."Last No. Used" := '';
    end;

    internal procedure DeleteSequence(var NoSeriesLine: Record "No. Series Line")
    begin
        if NoSeriesLine."Sequence Name" = '' then
            exit;
        if NumberSequence.Exists(NoSeriesLine."Sequence Name") then
            NumberSequence.Delete(NoSeriesLine."Sequence Name");
    end;

    internal procedure GetFormattedNo(NoSeriesLine: Record "No. Series Line"; Number: BigInteger): Code[20]
    var
        NumberCode: Code[20];
        i: Integer;
        j: Integer;
    begin
        if Number < NoSeriesLine."Starting Sequence No." then
            exit('');
        NumberCode := Format(Number);
        if NoSeriesLine."Starting No." = '' then
            exit(NumberCode);
        i := StrLen(NoSeriesLine."Starting No.");
        while (i > 1) and not (NoSeriesLine."Starting No."[i] in ['0' .. '9']) do
            i -= 1;
        j := i - StrLen(NumberCode);
        if (j > 0) and (i < MaxStrLen(NoSeriesLine."Starting No.")) then
            exit(CopyStr(NoSeriesLine."Starting No.", 1, j) + NumberCode + CopyStr(NoSeriesLine."Starting No.", i + 1));
        if (j > 0) then
            exit(CopyStr(NoSeriesLine."Starting No.", 1, j) + NumberCode);
        while (i > 1) and (NoSeriesLine."Starting No."[i] in ['0' .. '9']) do
            i -= 1;
        if (i > 0) and (i + StrLen(NumberCode) <= MaxStrLen(NumberCode)) then
            if (i = 1) and (NoSeriesLine."Starting No."[i] in ['0' .. '9']) then
                exit(NumberCode)
            else
                exit(CopyStr(NoSeriesLine."Starting No.", 1, i) + NumberCode);
        exit(NumberCode);
    end;

    internal procedure ExtractNoFromCode(NumberCode: Code[20]): BigInteger
    var
        i: Integer;
        j: Integer;
        Number: BigInteger;
        NoCodeSnip: Code[20];
    begin
        if NumberCode = '' then
            exit(0);
        i := StrLen(NumberCode);
        while (i > 1) and not (NumberCode[i] in ['0' .. '9']) do
            i -= 1;
        if i = 1 then begin
            if Evaluate(Number, Format(NumberCode[1])) then
                exit(Number);
            exit(0);
        end;
        j := i;
        while (i > 1) and (NumberCode[i] in ['0' .. '9']) do
            i -= 1;
        if (i = 1) and (NumberCode[i] in ['0' .. '9']) then
            i -= 1;
        NoCodeSnip := CopyStr(CopyStr(NumberCode, i + 1, j - i), 1, MaxStrLen(NoCodeSnip));
        if StrLen(NoCodeSnip) > 18 then
            Error(NoOverFlowErr, NumberCode, StrLen(NoCodeSnip));
        Evaluate(Number, NoCodeSnip);
        exit(Number);
    end;

    internal procedure DeleteNoSeries(var NoSeries: Record "No. Series")
    var
        NoSeriesLine: Record "No. Series Line";
        NoSeriesRelationship: Record "No. Series Relationship";
#if not CLEAN24
#pragma warning disable AL0432
        NoSeriesLineSales: Record "No. Series Line Sales";
        NoSeriesLinePurchase: Record "No. Series Line Purchase";
#pragma warning restore AL0432
#endif
    begin
        NoSeriesLine.SetRange("Series Code", NoSeries.Code);
        NoSeriesLine.DeleteAll();

#if not CLEAN24
#pragma warning disable AL0432
        NoSeriesLineSales.SetRange("Series Code", NoSeries.Code);
        NoSeriesLineSales.DeleteAll();

        NoSeriesLinePurchase.SetRange("Series Code", NoSeries.Code);
        NoSeriesLinePurchase.DeleteAll();
#pragma warning restore AL0432
#endif

        NoSeriesRelationship.SetRange(Code, NoSeries.Code);
        NoSeriesRelationship.DeleteAll();
        NoSeriesRelationship.SetRange(Code);

        NoSeriesRelationship.SetRange("Series Code", NoSeries.Code);
        NoSeriesRelationship.DeleteAll();
        NoSeriesRelationship.SetRange("Series Code");
    end;

    local procedure GetNoText(No: Code[20]): Code[20]
    var
        StartPos: Integer;
        EndPos: Integer;
    begin
        GetIntegerPos(No, StartPos, EndPos);
        if StartPos <> 0 then
            exit(CopyStr(CopyStr(No, StartPos, EndPos - StartPos + 1), 1, 20));
    end;

    local procedure GetIntegerPos(No: Code[20]; var StartPos: Integer; var EndPos: Integer)
    var
        IsDigit: Boolean;
        i: Integer;
    begin
        StartPos := 0;
        EndPos := 0;
        if No <> '' then begin
            i := StrLen(No);
            repeat
                IsDigit := No[i] in ['0' .. '9'];
                if IsDigit then begin
                    if EndPos = 0 then
                        EndPos := i;
                    StartPos := i;
                end;
                i := i - 1;
            until (i = 0) or (StartPos <> 0) and not IsDigit;
        end;
    end;

    local procedure UpdateLength(No: Code[20]; var MaxLength: Integer)
    var
        Length: Integer;
    begin
        if No <> '' then begin
            Length := StrLen(DelChr(GetNoText(No), '<', '0'));
            if Length > MaxLength then
                MaxLength := Length;
        end;
    end;

    local procedure UpdateNo(var No: Code[20]; NewNo: Code[20]; Length: Integer)
    var
        StartPos: Integer;
        EndPos: Integer;
        TempNo: Code[20];
    begin
        if No <> '' then
            if Length <> 0 then begin
                No := DelChr(GetNoText(No), '<', '0');
                TempNo := No;
                No := NewNo;
                NewNo := TempNo;
                GetIntegerPos(No, StartPos, EndPos);
                ReplaceNoText(No, NewNo, Length, StartPos, EndPos);
            end;
    end;

    local procedure ReplaceNoText(var No: Code[20]; NewNo: Code[20]; FixedLength: Integer; StartPos: Integer; EndPos: Integer)
    var
        StartNo: Code[20];
        EndNo: Code[20];
        ZeroNo: Code[20];
        NewLength: Integer;
        OldLength: Integer;
    begin
        if StartPos > 1 then
            StartNo := CopyStr(CopyStr(No, 1, StartPos - 1), 1, MaxStrLen(StartNo));
        if EndPos < StrLen(No) then
            EndNo := CopyStr(CopyStr(No, EndPos + 1), 1, MaxStrLen(EndNo));
        NewLength := StrLen(NewNo);
        OldLength := EndPos - StartPos + 1;
        if FixedLength > OldLength then
            OldLength := FixedLength;
        if OldLength > NewLength then
            ZeroNo := CopyStr(PadStr('', OldLength - NewLength, '0'), 1, MaxStrLen(ZeroNo));
        if StrLen(StartNo) + StrLen(ZeroNo) + StrLen(NewNo) + StrLen(EndNo) > 20 then
            Error(NumberLengthErr, No);
        No := CopyStr(StartNo + ZeroNo + NewNo + EndNo, 1, MaxStrLen(No));
    end;

    [EventSubscriber(ObjectType::Table, Database::"No. Series Line", 'OnAfterDeleteEvent', '', false, false)]
    local procedure OnDeleteNoSeriesLine(var Rec: Record "No. Series Line"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;

        if Rec."Sequence Name" <> '' then
            if NumberSequence.Exists(Rec."Sequence Name") then
                NumberSequence.Delete(Rec."Sequence Name");
    end;
}