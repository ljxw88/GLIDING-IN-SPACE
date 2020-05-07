--
-- Jiaxu Liu, Australia, September 2019
--
package StageD_Manager is

   protected Manager is

      entry Add_Itself (Vehicle_Number : Integer);

      entry Is_Full (Vehicle_Number : Integer; Ans : in out Boolean);

   end Manager;

end StageD_Manager;
