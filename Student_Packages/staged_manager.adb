--
-- Jiaxu Liu, Australia, September 2019
--
with Ada.Real_Time;         use Ada.Real_Time;
with Swarm_Structures_Base; use Swarm_Structures_Base;
with Vehicle_Interface;     use Vehicle_Interface;
with Ada.Text_IO;                use Ada.Text_IO;

package body StageD_Manager is

   Vehicle_Queue : array (1 .. 500) of Integer;
   Pointer : Positive := 1;

   protected body Manager is

      entry Add_Itself (Vehicle_Number : Integer) when Pointer <= Vehicle_Interface.Target_No_of_Elements is
         Im_In_Queue : Boolean := False;
      begin
         for i in Integer range 1 .. Pointer loop
            if Vehicle_Number = Vehicle_Queue (i) then
               Im_In_Queue := True;
            end if;
            exit when Im_In_Queue;
         end loop;
         if not Im_In_Queue then
            -- Put_Line (Integer'Image (Vehicle_Number));
            Vehicle_Queue (Pointer) := Vehicle_Number;
            Pointer := Pointer + 1;
         end if;
      end Add_Itself;

      entry Is_Full (Vehicle_Number : Integer; Ans : in out Boolean) when True is
         Im_In_Queue : Boolean := False;
      begin
         for i in Integer range 1 .. Pointer loop
            if Vehicle_Number = Vehicle_Queue (i) then
               Im_In_Queue := True;
            end if;
            exit when Im_In_Queue;
         end loop;
         if Pointer = Vehicle_Interface.Target_No_of_Elements + 1 and then Im_In_Queue = False then
            Ans := True;
            -- Put_Line (Positive'Image (Vehicle_Number) & ":Can kill");
         else
            -- Put_Line (Positive'Image (Vehicle_Number) & ":Can not kill");
            Ans := False;
         end if;
      end Is_Full;

   end Manager;

end StageD_Manager;
