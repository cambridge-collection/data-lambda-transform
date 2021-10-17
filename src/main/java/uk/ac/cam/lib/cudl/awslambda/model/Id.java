package uk.ac.cam.lib.cudl.awslambda.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.beans.ConstructorProperties;
import java.nio.file.Path;

public class Id implements Comparable<Id> {

    private final String id;

    @ConstructorProperties({"id"})
    @JsonCreator(mode = JsonCreator.Mode.PROPERTIES)
    public Id(@JsonProperty("@id") String id) {
        this.id = id;
    }

    public Id(Path id) {
        this(id.toString());
    }

    @JsonProperty("@id")
    public String getId() {
        return id;
    }

    @Override
    public String toString() {
        StringBuffer sb = new StringBuffer();
        sb.append("class Id {\n");
        sb.append("    @id: ").append(toIndentedString(id)).append("\n");
        sb.append("}");
        return sb.toString();
    }

    /**
     * Convert the given object to string with each line indented by 4 spaces
     * (except the first line).
     */
    private String toIndentedString(Object o) {
        if (o == null) {
            return "null";
        }
        return o.toString().replace("\n", "\n    ");
    }

    @Override
    public boolean equals(Object obj) {
        if (obj instanceof Id) {
            return getId().equals(((Id) obj).getId());
        }
        return false;
    }

    @Override
    public int hashCode() {
        return getId().hashCode();
    }

    @Override
    public int compareTo(Id id) {
        return this.getId().compareTo(id.getId());
    }
}
