import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class Main {
    public static void main(String[] args) {
        String url = "jdbc:mysql://localhost:3306/sat";
        String user = "root";
        String password = "***";

        try {
            Connection mydb = DriverManager.getConnection(url, user, password);

            String sql = "SELECT * FROM Satellite WHERE stato = 'working'";
            PreparedStatement mycursor = mydb.prepareStatement(sql);

            ResultSet myresult = mycursor.executeQuery();
            
            while (myresult.next()) {
                int id = myresult.getInt("id");
                String ente = myresult.getString("nome_ente");
                String anno_fine_servizio = myresult.getString("anno_fine_servizio");
                String data_lancio = myresult.getString("data_lancio");

                System.out.println("ID: " + id + ", Ente: " + ente + ", Anno Fine Servizio: " + anno_fine_servizio + ", Data Lancio: " + data_lancio);
            }
        } catch (SQLException e) {
            System.out.println("SQL Exception: " + e.getMessage());
        }
    }
}