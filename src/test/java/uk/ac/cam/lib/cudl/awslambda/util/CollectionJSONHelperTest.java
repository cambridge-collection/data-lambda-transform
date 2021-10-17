package uk.ac.cam.lib.cudl.awslambda.util;

import org.apache.commons.io.FileUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import uk.ac.cam.lib.cudl.awslambda.model.CollectionJSON;

import java.io.File;
import java.io.IOException;

import static org.junit.jupiter.api.Assertions.assertEquals;

class CollectionJSONHelperTest {

    private JSONHelper JSONHelper;

    @Test
    void getCollection() throws IOException {

        String json_in = FileUtils.readFileToString(new File("src/test/resources/json/source.test.collection.json"), "UTF-8");

        CollectionJSON CollectionJSON = JSONHelper.getCollection(json_in);
        assertEquals("hebrew", CollectionJSON.getName().getUrlSlug());
        assertEquals("Hebrew Manuscripts ", CollectionJSON.getName().getSort());
        assertEquals("Hebrew Manuscripts", CollectionJSON.getName().getFull());
        assertEquals("The University of Manchester Library holds over 400 Hebrew manuscripts. They include de luxe decorated manuscripts such as the famous Rylands Haggadah; rare and unique items which illuminate marginal forms of Judaism; a collection of Ketubbot (marriage contracts); and amulets and other magical texts assembled by Moses Gaster.",
                CollectionJSON.getDescription().getMedium());
        assertEquals("../items/data/tei/MS-HEBREW-GASTER-00086/MS-HEBREW-GASTER-00086.xml", CollectionJSON.getItemIds().get(0).getId());

    }

    @BeforeEach
    void setUp() {
        JSONHelper = new JSONHelper();
    }
}