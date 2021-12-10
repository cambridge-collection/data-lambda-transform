package uk.ac.cam.lib.cudl.awslambda.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.beans.ConstructorProperties;
import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public class UIThemeData {

    @JsonProperty("collections")
    private final List<UICollection> collections;

    @ConstructorProperties({"collections"})
    @JsonCreator(mode = JsonCreator.Mode.PROPERTIES)
    public UIThemeData(@JsonProperty("collections") List<UICollection> collections) {
        this.collections = collections;
    }

    @JsonProperty("collections")
    public List<UICollection> getCollections() {
        return collections;
    }

    @Override
    public String toString() {
        StringBuffer sb = new StringBuffer();
        sb.append("{\n");
        sb.append("    \"collections\": ").append(toIndentedString(collections)).append("\n");
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
}
