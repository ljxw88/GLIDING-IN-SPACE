-- Suggestions for packages which might be useful:

with Ada.Real_Time;         use Ada.Real_Time;
with Swarm_Structures_Base; use Swarm_Structures_Base;

package Vehicle_Message_Type is

   -- Replace this record definition by what your vehicles need to communicate.
   type ItemList is array( positive range <> ) of integer;
   type Broadcast_Array_Type_StageD2 is record
      Update_Time : Time := Clock;
      Alive_Vehicle : ItemList(1..500);
   end record;

   type Inter_Vehicle_Messages is record

      Current_Time : Ada.Real_Time.Time := Clock;
      Closest_Globe : Energy_Globe;
      Condition : Integer := 0;

      -- This Array is for Stage D, method 2
      No_Array : Broadcast_Array_Type_StageD2;

   end record;

end Vehicle_Message_Type;
