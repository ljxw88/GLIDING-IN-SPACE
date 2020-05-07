-- Suggestions for packages which might be useful:

with Ada.Real_Time;              use Ada.Real_Time;
with Ada.Text_IO;                use Ada.Text_IO;
with Exceptions;                 use Exceptions;
with Real_Type;                  use Real_Type;
--  with Generic_Sliding_Statistics;
with Rotations;                  use Rotations;
with Vectors_3D;                 use Vectors_3D;
with Vehicle_Interface;          use Vehicle_Interface;
with Vehicle_Message_Type;       use Vehicle_Message_Type;
--  with Swarm_Structures;           use Swarm_Structures;
with Swarm_Structures_Base;      use Swarm_Structures_Base;
-- with Ada.Numerics.Generic_Elementary_Functions;
-- with Swarm_Configuration;
with StageD_Manager;

package body Vehicle_Task_Type is

   function Get_Distance (coordinateA, coordinateB : Positions) return Real is
   begin
      return (abs (coordinateA - coordinateB)) ** 2;
   end Get_Distance;

   function Get_Closest_Globe (Pos : Positions; Energy_Globe_Array : Energy_Globes) return Energy_Globe is
      Temp_Closest_Globe : Energy_Globe;
   begin
      Temp_Closest_Globe := Energy_Globe_Array (1);
      for i in Integer range 1 .. Energy_Globe_Array'Length loop
         if Get_Distance (Pos, Energy_Globe_Array (i).Position) < Get_Distance (Pos, Temp_Closest_Globe.Position) then
            Temp_Closest_Globe := Energy_Globe_Array (i);
         end if;
      end loop;
      return Temp_Closest_Globe;
   end Get_Closest_Globe;

   procedure Compare_And_Update_StageD2 (LocalArray : in out Broadcast_Array_Type_StageD2; CompareArray : Broadcast_Array_Type_StageD2; VehicleNo : Positive) is
      Local_Length : Positive;
      Compare_Length : Positive;
   begin
      for i in LocalArray.Alive_Vehicle'Range loop
         if LocalArray.Alive_Vehicle (i) = Positive'Invalid_Value then
            Local_Length := i - 1;
            exit;
         end if;
      end loop;
      for i in CompareArray.Alive_Vehicle'Range loop
         if CompareArray.Alive_Vehicle (i) = Positive'Invalid_Value then
            Compare_Length := i - 1;
            exit;
         end if;
      end loop;
      if Compare_Length = Local_Length then
         if LocalArray.Update_Time > CompareArray.Update_Time then
            LocalArray := CompareArray;
         else
            null;
         end if;
      elsif Compare_Length > Local_Length then
         LocalArray := CompareArray;
      else
         null;
      end if;
      for i in Integer range 1 .. Target_No_of_Elements loop
         if LocalArray.Alive_Vehicle (i) = Positive'Invalid_Value then
            LocalArray.Alive_Vehicle (i) := VehicleNo;
            LocalArray.Update_Time := Clock;
            exit;
         end if;
         if LocalArray.Alive_Vehicle (i) = VehicleNo then
            exit;
         end if;
      end loop;

   end Compare_And_Update_StageD2;

   task body Vehicle_Task is
      -- If want to active stage d, set this to 1(method 1),2(method 2)
      Active_Stage_D : constant Integer := 0;

      Vehicle_No : Positive;
      -- You will want to take the pragma out, once you use the "Vehicle_No"

      Detected_Globes : Boolean := False; -- Has the vehicle detect globe itself
      Broadcasting_Message : Inter_Vehicle_Messages;
      Local_Message : Inter_Vehicle_Messages;

      -- Setting of vehicle basic condition
      -- 0. Default condition, for initialize
      Init_Condition : constant Integer := 0; -- This variable is not used, just demonstrated.
      -- 1. Haven't found the globe for time, request for globe message
      Requesting_Condition : constant Integer := 1;
      -- 2. Responding a request.
      Responding_Condition : constant Integer := 2;

      -- Setting of longest message catching latency & low battery level etc.
      Low_Battery_Level : constant Vehicle_Charges := 0.5;
      Speed_To_Depart : constant Throttle_T := 0.6;
      Attempt_Duration : constant Duration := 0.0;

      Time_Stamp_StageD : constant Duration := 10.0;-- Stage D delay time, before killing itself
      Local_Starting_Time : constant Time := Clock;

      Need_To_Exit : Boolean := False;

   begin
      -- You need to react to this call and provide your task_id.
      -- You can e.g. employ the assigned vehicle number (Vehicle_No)
      -- in communications with other vehicles.

      accept Identify (Set_Vehicle_No : Positive; Local_Task_Id : out Task_Id) do
         Vehicle_No     := Set_Vehicle_No;
         Local_Task_Id  := Current_Task;
      end Identify;

      -- Replace the rest of this task with your own code.
      -- Maybe synchronizing on an external event clock like "Wait_For_Next_Physics_Update",
      -- yet you can synchronize on e.g. the real-time clock as well.

      Local_Message.No_Array.Alive_Vehicle (1) := Vehicle_No;
      Local_Message.No_Array.Update_Time := Clock;
      Broadcasting_Message.No_Array.Alive_Vehicle (1) := Vehicle_No;
      Broadcasting_Message.No_Array.Update_Time := Clock;

      -- Without control this vehicle will go for its natural swarming instinct.
      select

         Flight_Termination.Stop;

      then abort

         Outer_task_loop : loop

            Wait_For_Next_Physics_Update;

            -- Your vehicle should respond to the world here: sense, listen, talk, act?

            if Active_Stage_D = 2 then -- Active stage d in method 2
               if To_Duration (Clock - Local_Starting_Time) > Time_Stamp_StageD then
                  -- Put_Line ("hi");
                  declare
                     In_Array : Boolean := False;
                  begin
                     for i in Integer range 1 .. Target_No_of_Elements loop
                        if Local_Message.No_Array.Alive_Vehicle (i) = Vehicle_No then
                           In_Array := True;
                           Put_Line (Integer'Image (Vehicle_No));
                        end if;
                     end loop;
                     if not In_Array then
                        Set_Throttle (0.0);
                        exit Outer_task_loop;
                     end if;
                  end;
               end if;
            end if;

            -- If get globes in this->task around
            if Energy_Globes_Around'Length /= 0 then
               Detected_Globes := True;
               -- Get globes information into message
               Broadcasting_Message.Closest_Globe := Get_Closest_Globe (Position, Energy_Globes_Around);
               Broadcasting_Message.Current_Time := Clock;
               Broadcasting_Message.Condition := Responding_Condition;
               Local_Message := Broadcasting_Message;
               Send (Broadcasting_Message);
            end if;

            if not Detected_Globes then
               -- No Globes Around
               if Messages_Waiting then
                  Receive (Broadcasting_Message);

                  Detected_Globes := True;
                  -- Update message and set to newest
                  Broadcasting_Message.No_Array := Local_Message.No_Array;
                  Local_Message := Broadcasting_Message;

                  -- Execute stage d after received message
                  if Active_Stage_D = 2 then
                     Compare_And_Update_StageD2 (Local_Message.No_Array, Broadcasting_Message.No_Array, Vehicle_No);
                     Broadcasting_Message.No_Array := Local_Message.No_Array;
                  end if;

               else
                  null;
               end if;
            else
               -- Detected Globes
               declare
                  Message_Duration : constant Duration := To_Duration (Clock - Local_Message.Current_Time);
                  Expiration_Time : constant Duration := 0.5; -- Time limit of not catching new message
               begin
                  -- Try catching newer Message or broadcast newer Message
                  if Messages_Waiting then
                     Receive (Broadcasting_Message);

                     -- Execute stage d after received message
                     if Active_Stage_D = 2 then
                        Compare_And_Update_StageD2 (Local_Message.No_Array, Broadcasting_Message.No_Array, Vehicle_No);
                        Broadcasting_Message.No_Array := Local_Message.No_Array;
                     end if;

                     -- update the max number of vehicle
                     if Broadcasting_Message.Current_Time > Local_Message.Current_Time then
                        if Broadcasting_Message.Condition = Responding_Condition then
                           -- Found the new message which found the position of globe
                           Local_Message := Broadcasting_Message;
                        end if;
                     else
                        if Broadcasting_Message.Condition = Requesting_Condition then
                           -- This means the Updating message is not newer than 'local_message'
                           -- We should update the 'Broadcasting_Message' with the latest, then boardcast
                           Broadcasting_Message := Local_Message;
                           Broadcasting_Message.Condition := Responding_Condition;
                           Send (Broadcasting_Message);
                        end if;
                     end if;
                  end if;

                  if Message_Duration > Expiration_Time then
                     -- Did Not Catch Message For Long Time
                     Set_Throttle (Throttle_T (0.5));
                     Set_Destination (Local_Message.Closest_Globe.Position);
                     Local_Message.Condition := Requesting_Condition;
                     Send (Local_Message);
                  else
                     -- Message up to date, Keep boardcasting
                     Local_Message.Condition := Responding_Condition;
                     Send (Local_Message);
                  end if;

                  -- Enough battery life, Keep Active in orbit
                  if Current_Charge > Low_Battery_Level and then Message_Duration < Expiration_Time then
                     declare
                        Allowable_Max_Dist : constant Real := 0.1;
                        -- The radius for excursion
                        Excursion_Scalar : Real;
                        -- The total groups of orbits
                        Max_Orbit_Group : constant Positive := 7;
                        -- Max_Orbit_Group : Positive := Swarm_Configuration.Initial_No_of_Elements / 10;
                        -- Max_Orbit_Group : Positive := Guess_Max_Vehicles;
                        Orbit_Group : Positive := Max_Orbit_Group;
                     begin
                        if Get_Distance (Position, Local_Message.Closest_Globe.Position) < Allowable_Max_Dist then
                           -- Take over by spin around orbit
                           if Orbit_Group >= Max_Orbit_Group then
                              Orbit_Group := Max_Orbit_Group;
                           end if;
                           Excursion_Scalar := 1.5 + (Real (Vehicle_No mod Orbit_Group) * 0.11);
                           Set_Destination (Position * (Excursion_Scalar, Excursion_Scalar, Excursion_Scalar));
                           Set_Throttle (0.3 + Real (Vehicle_No mod Orbit_Group) * 0.1);

--                             Set_Destination (Rotate(Current_Vector => Position,
--                                                     Rotation_Axis  => Pitch_Axis,
--                                                     Rotation_Angle => 0.5));
                           Set_Throttle (0.3 + Real (Vehicle_No mod Orbit_Group) * 0.1);

                        else
                           Set_Destination (Local_Message.Closest_Globe.Position);
                           Set_Throttle (Speed_To_Depart);
                        end if;
                     end;
                  end if;

                  -- Low Battery
                  if Current_Charge < Low_Battery_Level then
                     -- Go straight to the globe with max speed
                     Local_Message.Condition := Requesting_Condition;
                     Send (Local_Message);
                     Set_Throttle (Throttle_T (1.0));
                     Set_Destination (Local_Message.Closest_Globe.Position);
                  end if;

                  -- Executing stage d with method 1
                  if Active_Stage_D = 1 then
                     select
                        StageD_Manager.Manager.Add_Itself (Vehicle_No);
                     or
                        delay Attempt_Duration;
                     end select;
                     declare
                        Ask : Boolean := False;
                     begin
                        select
                           StageD_Manager.Manager.Is_Full (Vehicle_No, Ask);
                           if Ask then
                              Need_To_Exit := True;
                              Set_Throttle (0.0);
                              Put_Line (Positive'Image (Vehicle_No) & ": Can Kill itself");
                           end if;
                        or
                           delay Attempt_Duration;
                        end select;
                     end;
                  end if;

               end;
            end if;

            exit Outer_task_loop when Need_To_Exit;
         end loop Outer_task_loop;

      end select;

   exception
      when E : others => Show_Exception (E);

   end Vehicle_Task;

end Vehicle_Task_Type;
